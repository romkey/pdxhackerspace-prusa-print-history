# Opening a sign-in link (GET) only shows a confirmation; signing in is a POST from that page.
class LoginLinksController < ApplicationController
  include EstablishesSession

  before_action :set_link

  def show
    response.headers['Cache-Control'] = 'no-store'
    render :show, status: @link ? :ok : :gone
  end

  def create
    unless @link&.consume
      @link = nil
      return render(:show, status: :gone)
    end

    establish_session(@link.user)
    redirect_to @link.return_to, notice: "Signed in as #{@link.user.display_name}."
  end

  private

  # Unknown, used and expired links all read the same. A link for an admin stops working if
  # admin links are switched off after it was sent.
  def set_link
    link = LoginLink.for_secret(params[:token])
    @link = link if link && link_allowed?(link)
  end

  def link_allowed?(link)
    return false unless link.usable? && Setting.login_links_enabled?

    !link.user.admin? || Setting.login_links_allow_admins?
  end
end
