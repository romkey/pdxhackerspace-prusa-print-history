require 'test_helper'

class JobLabelPrintServiceTest < ActiveSupport::TestCase
  setup do
    @job = jobs(:active_xl)
    @printer = label_printers(:front_desk)
  end

  test 'prints label pdf to configured printer' do
    CupsService.stub(:print_data, 'job-42') do
      job_id = JobLabelPrintService.call(job: @job, label_printer: @printer)

      assert_equal 'job-42', job_id
    end
  end

  test 'requires a configured label printer' do
    LabelPrinter.stub(:default, nil) do
      assert_raises(JobLabelPrintService::Error) do
        JobLabelPrintService.call(job: @job)
      end
    end
  end
end
