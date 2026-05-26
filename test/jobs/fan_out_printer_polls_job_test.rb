require 'test_helper'

class FanOutPrinterPollsJobTest < ActiveJob::TestCase
  setup do
    printers(:prusa_xl).update!(prusalink_key: 'k1')
    printers(:prusa_mk4).update!(prusalink_key: 'k2')
    printers(:prusa_mini).update!(prusalink_key: nil)
  end

  test 'enqueues a PrinterPollJob for every printer with a key' do
    assert_enqueued_jobs 2, only: PrinterPollJob do
      FanOutPrinterPollsJob.perform_now
    end

    enqueued_ids = enqueued_jobs.filter_map do |j|
      j[:args].first if j[:job] == PrinterPollJob
    end

    assert_includes enqueued_ids, printers(:prusa_xl).id
    assert_includes enqueued_ids, printers(:prusa_mk4).id
    assert_not_includes enqueued_ids, printers(:prusa_mini).id
  end
end
