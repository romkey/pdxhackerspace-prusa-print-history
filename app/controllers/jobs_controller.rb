class JobsController < ApplicationController
  before_action :require_login_or_internal, only: %i[index show]
  before_action :require_login, only: %i[claim unclaim]
  before_action :require_admin_or_internal, only: %i[clear_print unclear_print]
  before_action :require_admin, only: %i[update reprint_label]
  before_action :set_job, only: %i[show update claim unclaim clear_print unclear_print reprint_label]

  def index
    scope = base_scope.includes(:printer, :owner, :preview_image_attachment,
                                photo_captures: { image_attachment: :blob }).recent
    scope = scope.where(printer_id: params[:printer_id]) if params[:printer_id].present?

    scope = scope.where(owner_id: current_user.id) if params[:owner] == 'me' && logged_in?

    @pagy, @jobs = pagy(scope, limit: 25)
    @label_printers = LabelPrinter.ordered
    @default_label_printer = LabelPrinter.default
  end

  def show
    @events            = @job.events.recent.includes(photo_attachment: :blob)
    @telemetry         = @job.telemetry_readings.ordered
    @tools             = @job.tools
    @latest_reading    = @telemetry.last
    @chart_series      = JobTelemetryCharts.series_for(@telemetry.to_a, job: @job)
    @chart_options     = JobTelemetryCharts.chart_options(@job)
    @photos            = JobPhotosPresenter.new(@job)
    @timeline          = JobTimeline.new(@job, events: @job.events.ordered.to_a)
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

  def reprint_label
    unless @job.label_reprintable?
      redirect_to @job, alert: 'This label cannot be reprinted.'
      return
    end

    if LabelPrinter.default.nil?
      redirect_to @job, alert: 'No label printer configured.'
      return
    end

    cups_job_id = JobLabelPrintService.call(job: @job, label_printer: label_printer_for_clear)
    redirect_to @job, notice: "Label reprinted (job #{cups_job_id})."
  rescue JobLabelPrintService::Error, CupsService::PrintError => e
    redirect_to @job, alert: "Reprint failed: #{e.message}"
  end

  def unclear_print
    unless @job.cleared?
      redirect_to @job, alert: 'This print is not cleared.'
      return
    end

    @job.update!(
      cleared_at: nil,
      cleared_by: nil,
      clear_outcome: nil,
      clear_failure_reason: nil,
      clear_failure_detail: nil
    )
    redirect_to @job, notice: 'Print unclear.'
  end

  def clear_print
    unless @job.clearable?
      redirect_to @job, alert: 'This print cannot be cleared.'
      return
    end

    outcome = params[:outcome].to_s
    print_label = outcome == 'success' && params[:skip_label].blank?
    if print_label && LabelPrinter.default.nil?
      redirect_to @job, alert: 'No label printer configured.'
      return
    end

    result = perform_clear_print(outcome, print_label)
    redirect_to @job, notice: clear_notice(result, outcome)
  rescue JobClearPrintService::Error, CupsService::PrintError => e
    redirect_to @job, alert: "Clear print failed: #{e.message}"
  end

  private

  def perform_clear_print(outcome, print_label)
    JobClearPrintService.call(
      job: @job,
      cleared_by: current_user,
      outcome:,
      label_printer: label_printer_for_clear,
      failure_reason: params[:failure_reason],
      failure_detail: params[:failure_detail],
      print_label:
    )
  end

  def clear_notice(result, outcome)
    parts = [clear_outcome_notice(result, outcome)]
    parts << "Label job #{result.cups_job_id}." if result.cups_job_id.present?
    parts << 'Owner notified by email.' if result.notification.email_sent
    parts << 'Owner notified on Slack.' if result.notification.slack_sent
    parts << "Notifications: #{result.notification.errors.join('; ')}." if result.notification.errors.any?
    parts.join(' ')
  end

  def clear_outcome_notice(result, outcome)
    return 'Print marked failed.' unless outcome == 'success'
    return 'Print cleared and label sent.' if result.cups_job_id.present?

    'Print cleared without a receipt.'
  end

  def label_printer_for_clear
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
