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

    if LocalLoginRateLimiter.throttled?(request.remote_ip)
      redirect_to login_path, alert: 'Too many sign-in attempts. Try again in a few minutes.'
      return
    end

    user = LocalAdmin.authenticate(params[:email], params[:password])
    if user
      establish_session(user)
      LocalLoginRateLimiter.reset!(request.remote_ip)
      redirect_to stored_return_path, notice: "Signed in as #{user.display_name}."
    else
      LocalLoginRateLimiter.record_failure(request.remote_ip)
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
    establish_session(user)

    flash[:notice] = "Signed in as #{user.display_name}."
    warnings = []
    training_notice = PrusaTrainingNotice.for_auth(auth, user: user)
    warnings << training_notice if training_notice.present?
    warnings << admin_access_revoked_message if user.authentik_admin_revoked
    flash[:warning] = warnings.join(' ') if warnings.any?
    redirect_to stored_return_path
  end

  def establish_session(user)
    return_to = session[:return_to]
    reset_session
    session[:user_id] = user.id
    user.record_login!
    session[:return_to] = return_to if return_to.present?
  end

  def admin_access_revoked_message
    'Your admin access was removed by Authentik. Contact an administrator if this is unexpected.'
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
