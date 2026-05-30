class UsersController < ApplicationController
  before_action :require_admin

  def index
    @users = User.alphabetical.includes(owned_jobs: :printer)
  end
end
