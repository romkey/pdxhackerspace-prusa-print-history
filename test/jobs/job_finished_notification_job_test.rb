require 'test_helper'

class JobFinishedNotificationJobTest < ActiveJob::TestCase
  test 'notifies owner when print finishes' do
    job = jobs(:active_xl)
    job.update!(status: 'finished', ended_at: Time.current, finished_notified_at: nil)

    JobNotificationService.stub(:notify_print_finished, JobNotificationService::Result.new(
                                                          email_sent: true, slack_sent: false, errors: []
                                                        )) do
      JobFinishedNotificationJob.perform_now(job.id)
    end

    assert_not_nil job.reload.finished_notified_at
  end

  test 'does not notify twice' do
    job = jobs(:active_xl)
    job.update!(finished_notified_at: 1.hour.ago)

    assert_no_enqueued_jobs only: JobFinishedNotificationJob do
      JobFinishedNotificationJob.perform_now(job.id)
    end
  end
end
