# Starts a fresh signed-in session for a user, keeping only where they were headed.
module EstablishesSession
  extend ActiveSupport::Concern

  private

  def establish_session(user)
    return_to = session[:return_to]
    reset_session
    session[:user_id] = user.id
    user.record_login!
    session[:return_to] = return_to if return_to.present?
  end
end
