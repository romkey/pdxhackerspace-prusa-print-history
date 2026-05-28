require 'test_helper'

class JobLabelPrintServiceTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @job = jobs(:active_xl)
    @printer = label_printers(:front_desk)
  end

  test 'prints label via CUPS' do
    CupsService.stub(:print_data, 'job-99') do
      result = JobLabelPrintService.call(job: @job, label_printer: @printer)

      assert_equal 'job-99', result.job_id
      assert_not result.email_sent
      assert_not result.slack_sent
    end
  end

  test 'raises when no label printer configured' do
    LabelPrinter.delete_all
    assert_raises(JobLabelPrintService::Error) do
      JobLabelPrintService.call(job: @job, label_printer: nil)
    end
  end

  test 'sends email notification when requested' do
    ENV['SMTP_ADDRESS'] = 'smtp.example.com'

    CupsService.stub(:print_data, 'job-99') do
      assert_emails 1 do
        result = JobLabelPrintService.call(job: @job, label_printer: @printer, notify_email: true)

        assert result.email_sent
      end
    end
  ensure
    ENV.delete('SMTP_ADDRESS')
  end

  test 'records email error when SMTP is not configured' do
    ENV.delete('SMTP_ADDRESS')
    ENV.delete('MAIL_HOST')
    CupsService.stub(:print_data, 'job-99') do
      result = JobLabelPrintService.call(job: @job, label_printer: @printer, notify_email: true)

      assert_not result.email_sent
      assert_includes result.notification_errors.join, 'SMTP is not configured'
    end
  end

  test 'sends slack notification when requested and handle present' do
    @job.owner.update!(slack_handle: 'makerbot')
    CupsService.stub(:print_data, 'job-99') do
      Slack::Messenger.stub(:dm, { 'ok' => true }) do
        result = JobLabelPrintService.call(job: @job, label_printer: @printer, notify_slack: true)

        assert result.slack_sent
      end
    end
  end

  test 'records slack error when handle missing' do
    @job.owner.update!(slack_handle: nil)
    CupsService.stub(:print_data, 'job-99') do
      result = JobLabelPrintService.call(job: @job, label_printer: @printer, notify_slack: true)

      assert_not result.slack_sent
      assert_includes result.notification_errors.join, 'Slack'
    end
  end
end
