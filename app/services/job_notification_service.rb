class JobNotificationService
  Result = Data.define(:email_sent, :slack_sent, :errors)

  class << self
    def notify_print_finished(job)
      new(job, :finished).deliver
    end

    def notify_print_cleared(job)
      new(job, :cleared).deliver
    end
  end

  def initialize(job, event)
    @job = job
    @event = event
  end

  def deliver
    owner = @job.owner
    return Result.new(email_sent: false, slack_sent: false, errors: []) if owner.blank?

    errors = []
    email_sent = false
    slack_sent = false

    if owner.wants_email_notifications?
      email_sent, email_error = send_email
      errors << email_error if email_error.present?
    end

    if owner.wants_slack_notifications?
      slack_sent, slack_error = send_slack
      errors << slack_error if slack_error.present?
    end

    Result.new(email_sent:, slack_sent:, errors:)
  end

  private

  def send_email
    JobNotificationMailer.public_send(mailer_action, @job).deliver_now
    [true, nil]
  rescue StandardError => e
    Rails.logger.error("JobNotificationService: email failed for job #{@job.id}: #{e.message}")
    [false, "Email: #{e.message}"]
  end

  def send_slack
    Slack::Messenger.dm_with_attachment(
      user_id: @job.owner.slack_id,
      text: slack_text,
      attachment: JobNotificationPhoto.attachment_for(@job)
    )
    [true, nil]
  rescue StandardError => e
    Rails.logger.error("JobNotificationService: Slack failed for job #{@job.id}: #{e.message}")
    [false, "Slack: #{e.message}"]
  end

  def mailer_action
    @event == :finished ? :print_finished : :print_cleared
  end

  def slack_text
    JobNotificationPresenter.new(@job, event: @event).slack_text
  end
end
