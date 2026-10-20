require 'test_helper'

class DataRetentionCleanupJobTest < ActiveJob::TestCase
  test 'runs the cleaner' do
    PhotoCapture.create!(printer: Printer.first, captured_at: 5.months.ago)

    assert_difference -> { PhotoCapture.count }, -1 do
      DataRetentionCleanupJob.perform_now
    end
  end
end
