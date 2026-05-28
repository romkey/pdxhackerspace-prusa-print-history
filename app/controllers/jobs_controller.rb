class JobsController < ApplicationController
  before_action :require_login, only: %i[claim unclaim]
  before_action :require_admin, only: %i[update print_label]
  before_action :set_job,       only: %i[show update claim unclaim print_label]

  def index
    scope = base_scope.includes(:printer, :owner).recent
    scope = scope.where(printer_id: params[:printer_id]) if params[:printer_id].present?

    scope = scope.where(owner_id: current_user.id) if params[:owner] == 'me' && logged_in?

    @pagy, @jobs = pagy(scope, limit: 25)
  end

  def show
    @events            = @job.events.recent.includes(photo_attachment: :blob)
    @telemetry         = @job.telemetry_readings.ordered
    @tools             = @job.tools
    @latest_reading    = @telemetry.last
    @chart_series      = JobTelemetryCharts.series_for(@telemetry.to_a, job: @job)
    @chart_options     = JobTelemetryCharts.chart_options(@job)
    @photos            = JobPhotosPresenter.new(@job)
    @label_printers    = LabelPrinter.ordered
    @default_label_printer = LabelPrinter.default
  end

  def claim
    @job.update!(owner: current_user)
    redirect_to @job, notice: 'Claimed.'
  end

  def unclaim
    if admin? || @job.owner_id == current_user.id
      @job.update!(owner: nil)
      redirect_to @job, notice: 'Released.'
    else
      head :forbidden
    end
  end

  def update
    if @job.update(job_params)
      redirect_to @job, notice: 'Updated.'
    else
      render :show, status: :unprocessable_content
    end
  end

  def print_label
    unless @job.label_printable?
      redirect_to @job, alert: 'Labels can only be printed for in-progress or finished jobs.'
      return
    end

    label_printer = label_printer_for_print
    if label_printer.nil?
      redirect_to @job, alert: 'No label printer configured.'
      return
    end

    result = JobLabelPrintService.call(
      job: @job,
      label_printer:,
      notify_email: ActiveModel::Type::Boolean.new.cast(params[:notify_email]),
      notify_slack: ActiveModel::Type::Boolean.new.cast(params[:notify_slack])
    )

    redirect_to @job, notice: result.flash_notice(label_printer.name)
  rescue JobLabelPrintService::Error, CupsService::PrintError => e
    redirect_to @job, alert: "Print failed: #{e.message}"
  end

  private

  def label_printer_for_print
    printer_id = params[:label_printer_id].presence
    return LabelPrinter.find_by(id: printer_id) if printer_id

    LabelPrinter.default
  end

  def base_scope
    Job.all
  end

  def set_job
    @job = Job.find(params.expect(:id))
  end

  def job_params
    params.expect(job: [:owner_id])
  end
end
