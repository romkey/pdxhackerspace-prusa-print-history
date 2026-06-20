require 'test_helper'

class JobAttentionNotificationJobTest < ActiveJob::TestCase
  test 'notifies owner when print needs attention' do
    job = jobs(:active_xl)
    called = false

    JobNotificationService.stub(:notify_print_attention, lambda { |notified_job|
      called = true

      assert_equal job, notified_job
      JobNotificationService::Result.new(email_sent: true, slack_sent: false, errors: [])
    }) do
      JobAttentionNotificationJob.perform_now(job.id)
    end

    assert called
  end

  test 'skips when job has no owner' do
    job = jobs(:active_xl)
    job.update!(owner: nil)
    called = false

    JobNotificationService.stub(:notify_print_attention, lambda { |*_|
      called = true
      JobNotificationService::Result.new(email_sent: true, slack_sent: false, errors: [])
    }) do
      JobAttentionNotificationJob.perform_now(job.id)
    end

    assert_not called
  end
end
