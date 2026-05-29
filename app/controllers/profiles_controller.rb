class ProfilesController < ApplicationController
  before_action :require_login

  def show
    @user = current_user
  end

  def update
    if current_user.update(profile_params)
      redirect_to profile_path, notice: 'Notification settings saved.'
    else
      @user = current_user
      render :show, status: :unprocessable_content
    end
  end

  private

  def profile_params
    permitted = params.expect(user: %i[notify_via_email notify_via_slack slack_id])
    permitted[:notify_via_email] = ActiveModel::Type::Boolean.new.cast(permitted[:notify_via_email])
    permitted[:notify_via_slack] = ActiveModel::Type::Boolean.new.cast(permitted[:notify_via_slack])
    permitted
  end
end
