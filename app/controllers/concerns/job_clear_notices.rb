# Flash text summarizing what clearing a print did (label, notifications).
module JobClearNotices
  extend ActiveSupport::Concern

  private

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
end
