require 'test_helper'

class FanOutPrinterFirmwareChecksJobTest < ActiveJob::TestCase
  test 'enqueues a check only for printers with a connection' do
    printers(:prusa_xl).update!(prusalink_key: 'k1')
    printers(:prusa_mini).update!(prusalink_key: nil)

    FanOutPrinterFirmwareChecksJob.perform_now

    ids = enqueued_jobs.select { |j| j[:job] == PrinterFirmwareCheckJob }.map { |j| j[:args].first }

    assert_includes ids, printers(:prusa_xl).id
    assert_not_includes ids, printers(:prusa_mini).id
  end
end
