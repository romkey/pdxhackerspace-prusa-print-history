class JobLabelPrintService
  Result = Data.define(:job_id, :email_sent, :slack_sent, :notification_errors) do
    def flash_notice(label_printer_name)
      parts = ["Label sent to #{label_printer_name} (job #{job_id})."]
      parts << 'Email sent.' if email_sent
      parts << 'Slack message sent.' if slack_sent
      parts << "Notifications: #{notification_errors.join('; ')}." if notification_errors.any?
      parts.join(' ')
    end
  end

  class Error < StandardError; end

  def self.call(job:, label_printer: nil, notify_email: false, notify_slack: false)
    new(job:, label_printer:, notify_email:, notify_slack:).call
  end

  def initialize(job:, label_printer: nil, notify_email: false, notify_slack: false)
    @job = job
    @label_printer = label_printer || LabelPrinter.default
    @notify_email = notify_email
    @notify_slack = notify_slack
  end

  def call
    raise Error, 'No label printer configured' if @label_printer.nil?

    job_id = print_label_pdf

    email_sent, slack_sent, notification_errors = deliver_notifications

    Result.new(job_id:, email_sent:, slack_sent:, notification_errors:)
  end

  private

  def print_label_pdf
    pdf = JobLabelPdf.new(@job, thermal_width_mm: @label_printer.thermal_roll_width_mm || 80)
    CupsService.print_data(
      pdf.render,
      @label_printer.cups_printer_name,
      cups_printer_server: @label_printer.cups_printer_server,
      filename: "job_label_#{@job.id}.pdf",
      options: @label_printer.cups_options
    )
  end

  def deliver_notifications
    return [false, false, []] if @job.owner.blank?

    email_sent = false
    slack_sent = false
    notification_errors = []

    if @notify_email
      email_sent, email_error = send_email_notification
      notification_errors << email_error if email_error.present?
    end

    if @notify_slack
      slack_sent, slack_error = send_slack_notification
      notification_errors << slack_error if slack_error.present?
    end

    [email_sent, slack_sent, notification_errors]
  end

  def send_email_notification
    return [false, nil] if @job.owner.email.blank?

    JobLabelMailer.print_ready(@job).deliver_now
    [true, nil]
  rescue StandardError => e
    Rails.logger.error("JobLabelPrintService: email notification failed for job #{@job.id}: #{e.message}")
    [false, "Email: #{e.message}"]
  end

  def send_slack_notification
    handle = @job.owner.slack_handle
    return [false, 'Slack: no handle on owner profile'] if handle.blank?

    Slack::Messenger.dm(handle:, text: slack_message)
    [true, nil]
  rescue StandardError => e
    Rails.logger.error("JobLabelPrintService: Slack notification failed for job #{@job.id}: #{e.message}")
    [false, "Slack: #{e.message}"]
  end

  def slack_message
    parts = ["Your print *#{@job.filename}* is ready on *#{@job.printer.name}*."]
    parts << "Material: #{material_summary}." if material_summary != '—'
    parts.join(' ')
  end

  def material_summary
    materials = @job.tools.filter_map(&:material).uniq
    return '—' if materials.empty?

    materials.join(', ')
  end
end
