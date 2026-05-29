class ApplicationController < ActionController::Base
  include Pagy::Backend
  include ActiveStorage::SetCurrent

  allow_browser versions: :modern

  stale_when_importmap_changes

  helper_method :current_user, :logged_in?, :admin?, :internal_network?, :can_clear_prints?

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = session[:user_id] && User.find_by(id: session[:user_id])
  end

  def logged_in?
    current_user.present?
  end

  def admin?
    current_user&.admin?
  end

  def internal_network?
    InternalNetworks.include?(request.remote_ip)
  end

  def can_clear_prints?
    admin? || internal_network?
  end

  def require_login
    return if logged_in?

    session[:return_to] = request.get? ? request.fullpath : nil
    redirect_to login_path, alert: 'Please sign in to continue.'
  end

  def require_admin
    return if admin?

    if logged_in?
      head :forbidden
    else
      require_login
    end
  end

  def require_login_or_internal
    return if logged_in? || internal_network?

    require_login
  end

  def require_admin_or_internal
    return if admin? || internal_network?

    require_admin
  end
end
