class UsersController < ApplicationController
  before_action :require_admin
  before_action :set_user

  def update
    if @user.update(admin_user_params)
      redirect_back_or_to(root_path, notice: 'User updated.')
    else
      redirect_back_or_to(root_path, alert: @user.errors.full_messages.to_sentence)
    end
  end

  private

  def set_user
    @user = User.find(params.expect(:id))
  end

  def admin_user_params
    params.expect(user: %i[slack_id slack_handle])
  end
end
