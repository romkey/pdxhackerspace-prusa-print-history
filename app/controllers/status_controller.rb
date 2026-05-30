class StatusController < ApplicationController
  before_action :require_login_or_internal

  def printers
    render json: StatusExport.printers
  end

  def jobs
    render json: StatusExport.jobs
  end

  def events
    render json: StatusExport.events
  end
end
