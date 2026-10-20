require 'test_helper'

class DataRetentionCleanerTest < ActiveSupport::TestCase
  setup do
    @printer = Printer.first
    Setting.image_retention_months = '3'
    Setting.job_history_retention_months = '12'
    Setting.delete_job_history = '0'
  end

  test 'destroys photo captures older than the retention window only' do
    old = PhotoCapture.create!(printer: @printer, captured_at: 4.months.ago)
    recent = PhotoCapture.create!(printer: @printer, captured_at: 1.month.ago)

    DataRetentionCleaner.new.run!

    assert_not PhotoCapture.exists?(old.id)
    assert PhotoCapture.exists?(recent.id)
  end

  test 'keeps old job history unless enabled' do
    job = old_job

    DataRetentionCleaner.new.run!

    assert Job.exists?(job.id)
  end

  test 'deletes old terminal jobs when enabled but never active ones' do
    Setting.delete_job_history = '1'
    old = old_job
    active = old_job(status: 'printing')
    recent = old_job(ended_at: 1.month.ago)

    DataRetentionCleaner.new.run!

    assert_not Job.exists?(old.id)
    assert Job.exists?(active.id)
    assert Job.exists?(recent.id)
  end

  private

  def old_job(status: 'finished', ended_at: 13.months.ago)
    Job.create!(printer: @printer, filename: 'old.bgcode', status: status, started_at: ended_at - 1.hour,
                ended_at: ended_at)
  end
end
