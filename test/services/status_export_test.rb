require 'test_helper'

class StatusExportTest < ActiveSupport::TestCase
  test 'printers includes active job with progress nested under job' do
    job = jobs(:active_xl)
    job.update!(progress_percent: 42.5)

    payload = StatusExport.printers
    xl = payload.find { |entry| entry[:name] == 'Prusa XL' }

    assert xl
    assert_equal job.id, xl[:job][:id]
    assert_in_delta 42.5, xl[:job][:progress_percent]
    assert_equal 'printing', xl[:job][:status]
    assert_kind_of Array, xl[:heads]
    assert_not(payload.any? { |entry| entry.key?(:prusalink_key) })
  end

  test 'printers sets job to nil when idle' do
    Job.where(printer: printers(:prusa_mini)).destroy_all

    payload = StatusExport.printers
    mini = payload.find { |entry| entry[:name] == 'Prusa Mini' }

    assert mini
    assert_nil mini[:job]
  end

  test 'jobs returns recent jobs with printer summary and progress' do
    job = jobs(:active_xl)
    job.update!(progress_percent: 12.0)

    payload = StatusExport.jobs(limit: 10)
    entry = payload.find { |row| row[:id] == job.id }

    assert entry
    assert_in_delta 12.0, entry[:progress_percent]
    assert_equal 'Prusa XL', entry[:printer][:name]
  end

  test 'jobs respects limit' do
    assert_operator StatusExport.jobs(limit: 1).size, :<=, 1
  end

  test 'events returns recent events with nested job data' do
    event = job_events(:active_xl_attention)

    payload = StatusExport.events(limit: 10)
    entry = payload.find { |row| row[:id] == event.id }

    assert entry
    assert_equal 'attention', entry[:event_type]
    assert_equal event.job_id, entry[:job][:id]
    assert entry[:job].key?(:progress_percent)
  end

  test 'events respects limit' do
    assert_operator StatusExport.events(limit: 1).size, :<=, 1
  end
end
