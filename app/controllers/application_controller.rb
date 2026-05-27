class ApplicationController < ActionController::Base
  include Pagy::Backend
  include ActiveStorage::SetCurrent

  allow_browser versions: :modern

  stale_when_importmap_changes

  helper_method :current_user, :logged_in?, :admin?

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
end
