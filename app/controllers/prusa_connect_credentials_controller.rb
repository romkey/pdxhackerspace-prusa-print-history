class PrusaConnectCredentialsController < ApplicationController
  before_action :require_admin

  def update
    token = params[:refresh_token].to_s.strip
    return redirect_to settings_path, alert: 'Enter a refresh token.' if token.blank?

    PrusaConnectCredential.current!.reset_with_refresh_token!(token)
    redirect_to settings_path, notice: 'Prusa Connect token saved.'
  end

  def destroy
    PrusaConnectCredential.destroy_all
    redirect_to settings_path, notice: 'Prusa Connect token removed.'
  end
end
