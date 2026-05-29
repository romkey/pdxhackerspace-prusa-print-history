require 'test_helper'

class JobClearPrintServiceTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @job = jobs(:active_xl)
    @admin = users(:admin)
    @printer = label_printers(:front_desk)
  end

  test 'clears successful print and sends label' do
    JobLabelPrintService.stub(:call, 'job-99') do
      JobNotificationService.stub(:notify_print_cleared, JobNotificationService::Result.new(
                                                           email_sent: false, slack_sent: false, errors: []
                                                         )) do
        result = JobClearPrintService.call(
          job: @job,
          cleared_by: @admin,
          outcome: 'success',
          label_printer: @printer
        )

        assert_equal 'job-99', result.cups_job_id
        assert_equal 'success', @job.reload.clear_outcome
        assert_equal @admin, @job.cleared_by
      end
    end
  end

  test 'clears failed print without label' do
    JobNotificationService.stub(:notify_print_cleared, JobNotificationService::Result.new(
                                                         email_sent: false, slack_sent: false, errors: []
                                                       )) do
      result = JobClearPrintService.call(
        job: @job,
        cleared_by: @admin,
        outcome: 'failed',
        failure_reason: 'spaghetti'
      )

      assert_nil result.cups_job_id
      assert_equal 'failed', @job.reload.clear_outcome
      assert_equal 'spaghetti', @job.clear_failure_reason
    end
  end

  test 'requires details for other failure reason' do
    assert_raises(JobClearPrintService::Error) do
      JobClearPrintService.call(
        job: @job,
        cleared_by: @admin,
        outcome: 'failed',
        failure_reason: 'other',
        failure_detail: ''
      )
    end
  end
end
