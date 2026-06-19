class DashboardController < ApplicationController
  helper_method :dashboard_active_filters

  def index
    @printers = Printer.ordered.includes(:printer_heads, photo_captures: { image_attachment: :blob })
    active_jobs_by_printer, last_jobs_by_printer = dashboard_jobs_by_printer
    assign_label_printer_variables
    @presenter = DashboardPresenter.new(
      printers: @printers,
      active_jobs_by_printer: active_jobs_by_printer,
      last_jobs_by_printer: last_jobs_by_printer,
      recent_events: JobEvent.recent.includes(job: :printer).limit(15),
      filters: params[:filter],
      current_user: current_user
    )
  end

  def dashboard_active_filters
    @presenter&.active_filters || []
  end

  private

  def dashboard_jobs_by_printer
    active_jobs = Job.active
                     .where(printer_id: @printers.map(&:id))
                     .includes(:owner, :preview_image_attachment,
                               :telemetry_readings,
                               photo_captures: { image_attachment: :blob })
    active_jobs_by_printer = active_jobs.index_by(&:printer_id)
    last_jobs_by_printer = Job.where(printer_id: @printers.map(&:id))
                              .includes(:owner, :preview_image_attachment)
                              .recent
                              .to_a
                              .group_by(&:printer_id)
                              .transform_values(&:first)
    active_jobs_by_printer.each_key { |printer_id| last_jobs_by_printer.delete(printer_id) }
    [active_jobs_by_printer, last_jobs_by_printer]
  end

  def assign_label_printer_variables
    @label_printers = LabelPrinter.ordered
    @default_label_printer = LabelPrinter.default
  end
end
