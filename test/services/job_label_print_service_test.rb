require 'test_helper'

class JobLabelPrintServiceTest < ActiveSupport::TestCase
  setup do
    @job = jobs(:active_xl)
    @printer = label_printers(:front_desk)
  end

  test 'prints label pdf and sends cut command for thermal printer' do
    calls = []
    CupsService.stub(:print_data, lambda { |*_args, **_kwargs|
      calls << :print_data
      'job-42'
    }) do
      CupsService.stub(:print_cut, lambda { |*_args, **_kwargs|
        calls << :print_cut
        'cut-1'
      }) do
        job_id = JobLabelPrintService.call(job: @job, label_printer: @printer)

        assert_equal 'job-42', job_id
        assert_equal %i[print_data print_cut], calls
      end
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
