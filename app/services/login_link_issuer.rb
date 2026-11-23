# Creates a sign-in link for a member and delivers it. Raises LoginLinkIssuer::Error with an
# API error code and HTTP status when the request is not allowed.
class LoginLinkIssuer
  class Error < StandardError
    attr_reader :code, :status

    def initialize(message, code:, status: :forbidden)
      super(message)
      @code = code
      @status = status
    end
  end

  Result = Data.define(:link, :url)

  PURPOSES = %w[sign_in problem_report].freeze

  def self.call(...)
    new(...).call
  end

  # `display_allowed` says whether the caller may receive the link to show on its own screen
  # (a kiosk's QR code) rather than have it emailed. `link` may carry :return_to and :purpose.
  def initialize(user:, delivery: 'email', token: nil, display_allowed: false, **link)
    @user = user
    @delivery = delivery.to_s.presence || 'email'
    @token = token
    @display_allowed = display_allowed
    @return_to = link.fetch(:return_to, '/')
    @purpose = link.fetch(:purpose, 'sign_in')
  end

  def call
    check_allowed!
    link = LoginLink.create!(user: @user, return_to: @return_to, delivery: @delivery, requested_by_token: @token,
                             expires_at: lifetime.from_now)
    url = Rails.application.routes.url_helpers.login_link_url(link.secret, **AppUrl.options)
    LoginLinkMailer.sign_in_link(@user, url, link.expires_at, @purpose).deliver_later if @delivery == 'email'
    Result.new(link:, url:)
  end

  private

  def check_allowed!
    refuse!('Sign-in links are turned off.', :login_links_disabled) unless Setting.login_links_enabled?
    refuse!('Admins sign in through the normal sign-in page.', :admin_login_links_disabled) if admin_refused?
    check_delivery!
    return if LoginLink.recently_requested_count(@user) < LoginLink::REQUESTS_PER_PERIOD

    refuse!('Too many sign-in links requested. Try again in a few minutes.', :rate_limited, :too_many_requests)
  end

  def check_delivery!
    refuse!('Delivery must be "email" or "display".', :bad_request, :bad_request) unless delivery_valid?
    if @delivery == 'display'
      refuse!('This client may not display sign-in links.', :display_not_allowed) unless @display_allowed
    elsif !@user.email_notifications_available?
      refuse!('Email is not set up, so the link cannot be sent.', :email_unavailable, :service_unavailable)
    end
  end

  def delivery_valid?
    LoginLink::DELIVERIES.include?(@delivery)
  end

  def admin_refused?
    @user.admin? && !Setting.login_links_allow_admins?
  end

  def lifetime
    minutes = @delivery == 'display' ? Setting.login_link_qr_ttl_minutes : Setting.login_link_ttl_minutes
    (minutes || ApiSettings::NUMBER_DEFAULTS[:login_link_ttl_minutes]).minutes
  end

  def refuse!(message, code, status = :forbidden)
    raise Error.new(message, code: code.to_s, status:)
  end
end
