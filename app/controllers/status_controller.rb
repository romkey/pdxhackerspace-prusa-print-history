class StatusController < ApplicationController
  before_action :require_login_or_internal

  def printers
    render json: StatusExport.printers(**export_options)
  end

  def jobs
    render json: StatusExport.jobs(**export_options)
  end

  def events
    render json: StatusExport.events(**export_options)
  end

  private

  def export_options
    { include_email: logged_in? }
  end
end
