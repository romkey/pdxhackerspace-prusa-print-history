require 'test_helper'

class FanOutPrinterPhotoCapturesJobTest < ActiveJob::TestCase
  setup do
    printers(:prusa_xl).update!(camera_url: 'http://printer/snapshot.jpg', prusalink_key: 'k1')
    printers(:prusa_mk4).update!(prusalink_key: 'k2', camera_url: nil)
    printers(:prusa_mini).update!(prusalink_key: nil, camera_url: nil)
  end

  test 'enqueues capture jobs for printers with camera or PrusaLink' do
    assert_enqueued_jobs 2, only: PrinterPhotoCaptureJob do
      FanOutPrinterPhotoCapturesJob.perform_now
    end

    enqueued_ids = enqueued_jobs.filter_map do |job|
      job[:args].first if job[:job] == PrinterPhotoCaptureJob
    end

    assert_includes enqueued_ids, printers(:prusa_xl).id
    assert_includes enqueued_ids, printers(:prusa_mk4).id
    assert_not_includes enqueued_ids, printers(:prusa_mini).id
  end
end
