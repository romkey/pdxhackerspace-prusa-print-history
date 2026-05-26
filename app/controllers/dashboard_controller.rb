class DashboardController < ApplicationController
  def index
    @printers       = Printer.ordered.includes(:jobs)
    @active_jobs    = Job.active.recent.includes(:printer, :owner).limit(10)
    @recent_events  = JobEvent.recent.includes(job: :printer).limit(15)
    @ha_health      = Setting.home_assistant_health
  end
end
