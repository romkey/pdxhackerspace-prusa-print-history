class UsersController < ApplicationController
  before_action :require_admin

  def index
    @users = User.in_display_name_order(User.includes(owned_jobs: :printer))
  end
end
