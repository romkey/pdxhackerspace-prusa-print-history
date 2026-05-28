class DashboardController < ApplicationController
  def index
    @printers = Printer.ordered.includes(:printer_heads, photo_captures: { image_attachment: :blob })
    active_jobs = Job.active
                     .where(printer_id: @printers.map(&:id))
                     .includes(:preview_image_attachment,
                               :telemetry_readings,
                               photo_captures: { image_attachment: :blob })
    active_jobs_by_printer = active_jobs.index_by(&:printer_id)
    last_jobs_by_printer = Job.where(printer_id: @printers.map(&:id))
                              .includes(:preview_image_attachment)
                              .recent
                              .to_a
                              .group_by(&:printer_id)
                              .transform_values(&:first)
    active_jobs_by_printer.each_key { |printer_id| last_jobs_by_printer.delete(printer_id) }
    @presenter = DashboardPresenter.new(
      printers: @printers,
      active_jobs_by_printer: active_jobs_by_printer,
      last_jobs_by_printer: last_jobs_by_printer,
      recent_events: JobEvent.recent.includes(job: :printer).limit(15)
    )
  end
end
