class DashboardController < ApplicationController
  def index
    @printers = Printer.ordered.includes(:printer_heads, photo_captures: { image_attachment: :blob })
    active_jobs = Job.active
                     .where(printer_id: @printers.map(&:id))
                     .includes(:preview_image_attachment, photo_captures: { image_attachment: :blob })
    @presenter = DashboardPresenter.new(
      printers: @printers,
      active_jobs_by_printer: active_jobs.index_by(&:printer_id),
      recent_events: JobEvent.recent.includes(job: :printer).limit(15)
    )
  end
end
