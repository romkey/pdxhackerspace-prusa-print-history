# Starts a short kiosk session: a token that acts as one member, minted by a kiosk's device
# token after the kiosk has resolved a keyfob to that member's Authentik member ID. The
# session inherits the device token's access level and address limits, never has admin
# powers, and dies with the device token if that is paused or revoked.
class KioskSessionIssuer
  class Error < StandardError
    attr_reader :code, :status

    def initialize(message, code:, status:)
      super(message)
      @code = code
      @status = status
    end
  end

  DEFAULT_MINUTES = ApiSettings::NUMBER_DEFAULTS.fetch(:api_kiosk_session_minutes)

  def self.call(...)
    new(...).call
  end

  def initialize(device_token:, member_id:, ip: nil)
    @device_token = device_token
    @member_id = MemberIdClaim.normalize(member_id)
    @ip = ip
  end

  def call
    member = find_member!
    session = ApiToken.create!(kind: 'kiosk_session', user: member, parent_token: @device_token,
                               name: "Kiosk session: #{@device_token.name}".truncate(100),
                               access_level: @device_token.access_level,
                               allowed_cidrs: @device_token.allowed_cidrs, expires_at: lifetime.from_now)
    ApiTokenEvent.record!(action: 'api.kiosk.session_started', token: @device_token, actor: member, subject: member,
                          ip: @ip, detail: { kiosk_session_id: session.id })
    session
  end

  private

  def find_member!
    raise Error.new('member_id is required.', code: 'bad_request', status: :bad_request) if @member_id.nil?

    member = User.find_by(member_id: @member_id)
    if member.nil?
      raise Error.new('No member with that ID has signed in to this app yet. Sign in on the web once, then try again.',
                      code: 'member_not_found', status: :not_found)
    end
    return member unless ApiTokenRules.login_too_old?(member)

    raise Error.new('This member needs to sign in on the web again before using the kiosk.',
                    code: 'member_sign_in_required', status: :forbidden)
  end

  def lifetime
    (Setting.api_kiosk_session_minutes || DEFAULT_MINUTES).minutes
  end
end
