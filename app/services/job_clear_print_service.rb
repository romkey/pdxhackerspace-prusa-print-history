class JobClearPrintService
  Result = Data.define(:cups_job_id, :notification)

  class Error < StandardError; end

  ClearRequest = Data.define(:job, :cleared_by, :outcome, :label_printer, :failure_reason, :failure_detail)
  REQUEST_DEFAULTS = { label_printer: nil, failure_reason: nil, failure_detail: nil }.freeze

  def self.call(**attributes)
    new(ClearRequest.new(**REQUEST_DEFAULTS, **attributes)).call
  end

  def initialize(request)
    @job = request.job
    @cleared_by = request.cleared_by
    @outcome = request.outcome.to_s
    @label_printer = request.label_printer
    @failure_reason = request.failure_reason
    @failure_detail = request.failure_detail
  end

  def call
    validate!

    cups_job_id = nil
    cups_job_id = print_label if success?

    @job.update!(clear_attributes)
    notification = JobNotificationService.notify_print_cleared(@job)

    Result.new(cups_job_id:, notification:)
  end

  private

  def validate!
    validate_not_already_cleared!
    validate_outcome!
    validate_failure! unless success?
  end

  def validate_not_already_cleared!
    raise Error, 'Print has already been cleared' if @job.cleared_at.present?
  end

  def validate_outcome!
    raise Error, 'Invalid outcome' unless Job::CLEAR_OUTCOMES.include?(@outcome)
  end

  def validate_failure!
    raise Error, 'Failure reason is required' if @failure_reason.blank?
    raise Error, 'Invalid failure reason' unless Job::CLEAR_FAILURE_REASONS.key?(@failure_reason)
    return unless @failure_reason == 'other' && @failure_detail.blank?

    raise Error, 'Details are required for Other'
  end

  def success?
    @outcome == 'success'
  end

  def clear_attributes
    {
      cleared_at: Time.current,
      cleared_by: @cleared_by,
      clear_outcome: @outcome,
      clear_failure_reason: success? ? nil : @failure_reason,
      clear_failure_detail: success? || @failure_reason != 'other' ? nil : @failure_detail.to_s.strip
    }
  end

  def print_label
    printer = @label_printer || LabelPrinter.default
    raise Error, 'No label printer configured' if printer.nil?

    pdf = JobLabelPdf.new(@job, thermal_width_mm: printer.thermal_roll_width_mm || 80)
    CupsService.print_data(
      pdf.render,
      printer.cups_printer_name,
      cups_printer_server: printer.cups_printer_server,
      filename: "job_label_#{@job.id}.pdf",
      options: printer.cups_options
    )
  end
end
