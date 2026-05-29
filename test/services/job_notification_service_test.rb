require 'test_helper'

class JobNotificationServiceTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @job = jobs(:active_xl)
    @job.owner.update!(notify_via_email: true, notify_via_slack: false)
  end

  test 'sends finished email when user prefers email and SMTP configured' do
    ENV['SMTP_SERVER'] = 'smtp.example.com'

    assert_emails 1 do
      result = JobNotificationService.notify_print_finished(@job)

      assert result.email_sent
    end
  ensure
    ENV.delete('SMTP_SERVER')
  end

  test 'sends cleared slack when user prefers slack and slack id present' do
    ENV['SLACK_API_TOKEN'] = 'xoxb-test'
    @job.owner.update!(notify_via_email: false, notify_via_slack: true, slack_id: 'U123')

    Slack::Messenger.stub(:dm_with_attachment, { 'ok' => true }) do
      @job.update!(clear_outcome: 'success', cleared_at: Time.current)
      result = JobNotificationService.notify_print_cleared(@job)

      assert result.slack_sent
    end
  ensure
    ENV.delete('SLACK_API_TOKEN')
  end

  test 'skips notifications when owner has none enabled' do
    @job.owner.update!(notify_via_email: false, notify_via_slack: false)

    result = JobNotificationService.notify_print_finished(@job)

    assert_not result.email_sent
    assert_not result.slack_sent
  end
end
