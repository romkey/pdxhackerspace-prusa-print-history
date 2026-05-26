class SessionsController < ApplicationController
  skip_forgery_protection only: %i[create failure]

  def new
    redirect_to root_path if logged_in?
  end

  def create
    user = User.find_or_create_from_auth(auth_hash)
    session[:user_id] = user.id
    redirect_to stored_return_path, notice: "Signed in as #{user.display_name}."
  end

  def destroy
    reset_session
    redirect_to root_path, notice: 'Signed out.'
  end

  def failure
    redirect_to login_path, alert: "Sign-in failed: #{params[:message] || 'unknown error'}"
  end

  private

  def auth_hash
    request.env.fetch('omniauth.auth')
  end

  def stored_return_path
    target = session.delete(:return_to)
    target.presence || root_path
  end
end
