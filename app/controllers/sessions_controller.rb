class SessionsController < ApplicationController
  skip_forgery_protection only: %i[create failure]

  def new
    redirect_to root_path if logged_in?
  end

  def create
    auth = auth_hash
    AuthentikDebug.log_auth_hash(auth)
    sign_in_user(User.find_or_create_from_auth(auth), auth: auth)
  rescue KeyError => e
    handle_sign_in_error(
      e,
      context: 'callback missing auth payload',
      message: 'Authentik did not return account information.'
    )
  rescue ActiveRecord::RecordInvalid => e
    handle_sign_in_error(
      e,
      context: 'callback user save',
      message: e.record.errors.full_messages.to_sentence
    )
  rescue StandardError => e
    handle_sign_in_error(e, context: 'callback')
  end

  def create_local
    unless LocalAdmin.configured?
      head :not_found
      return
    end

    user = LocalAdmin.authenticate(params[:email], params[:password])
    if user
      session[:user_id] = user.id
      redirect_to stored_return_path, notice: "Signed in as #{user.display_name}."
    else
      redirect_to login_path, alert: 'Invalid email or password.'
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: 'Signed out.'
  end

  def failure
    if logged_in?
      redirect_to stored_return_path, notice: "Signed in as #{current_user.display_name}."
      return
    end

    report = OmniauthFailureReporter.report(request)
    redirect_to login_path, alert: report.user_message
  end

  private

  def sign_in_user(user, auth:)
    return_to = session[:return_to]
    reset_session
    session[:user_id] = user.id
    session[:return_to] = return_to if return_to.present?

    flash[:notice] = "Signed in as #{user.display_name}."
    training_notice = PrusaTrainingNotice.for_auth(auth, user: user)
    flash[:warning] = training_notice if training_notice.present?
    redirect_to stored_return_path
  end

  def handle_sign_in_error(error, context:, message: nil)
    OmniauthFailureReporter.log_sign_in_error(request, error, context: context)
    detail = message || OmniauthFailureReporter.safe_error_message(error)
    redirect_to login_path, alert: "Sign-in failed: #{detail}."
  end

  def auth_hash
    request.env.fetch('omniauth.auth')
  end

  def stored_return_path
    target = session.delete(:return_to)
    target.presence || root_path
  end
end
