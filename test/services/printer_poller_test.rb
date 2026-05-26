require 'test_helper'

class PrinterPollerTest < ActiveJob::TestCase
  setup do
    @printer = printers(:prusa_mini) # no jobs in fixtures
    @printer.update!(prusalink_key: 'key', camera_url: 'http://printer/snapshot.jpg')
  end

  test 'creates a job, telemetry reading, and started event on first poll' do
    payloads = {
      status: { 'printer' => { 'state' => 'PRINTING', 'temp_bed' => 60.0, 'temp_nozzle' => 215.0 } },
      job: { 'id' => 'pl-555', 'file' => { 'display_name' => 'thing.gcode' } }
    }

    prusalink = stub_prusalink(payloads)
    ha = stub_home_assistant(temperatures: { @printer.enclosure_temp_sensor => nil })

    assert_difference -> { Job.count } => 1,
                      -> { TelemetryReading.count } => 1,
                      -> { JobEvent.count } => 1 do
      PrinterPoller.new(@printer, prusalink: prusalink, home_assistant: ha).poll!
    end

    job = Job.find_by!(prusalink_job_id: 'pl-555')

    assert_equal 'printing', job.status
    assert_equal 'thing.gcode', job.filename
    assert_equal 'started', job.events.last.event_type
  end

  test 'records a status_change event when status flips' do
    job = @printer.jobs.create!(filename: 'thing.gcode', status: 'printing',
                                prusalink_job_id: 'pl-555', started_at: 5.minutes.ago)
    job.events.create!(event_type: 'started', to_status: 'printing', occurred_at: 5.minutes.ago)

    payloads = {
      status: { 'printer' => { 'state' => 'ATTENTION' } },
      job: { 'id' => 'pl-555', 'file' => { 'display_name' => 'thing.gcode' } }
    }
    prusalink = stub_prusalink(payloads)
    ha = stub_home_assistant

    assert_enqueued_with(job: CaptureEventPhotoJob) do
      PrinterPoller.new(@printer, prusalink: prusalink, home_assistant: ha).poll!
    end

    assert_equal 'attention', job.reload.status
    assert_equal 'attention', job.events.recent.first.event_type
  end

  test 'finalizes job on finished status' do
    job = @printer.jobs.create!(filename: 'thing.gcode', status: 'printing',
                                prusalink_job_id: 'pl-555', started_at: 1.hour.ago)
    job.events.create!(event_type: 'started', to_status: 'printing', occurred_at: 1.hour.ago)

    payloads = {
      status: { 'printer' => { 'state' => 'FINISHED' } },
      job: { 'id' => 'pl-555', 'file' => { 'display_name' => 'thing.gcode' }, 'time_printing' => 3600 }
    }
    prusalink = stub_prusalink(payloads)

    PrinterPoller.new(@printer, prusalink: prusalink, home_assistant: stub_home_assistant).poll!

    job.reload

    assert_equal 'finished', job.status
    assert_not_nil job.ended_at
    assert_equal 3600, job.total_duration_seconds
    assert_equal 'finished', job.events.recent.first.event_type
  end

  test 'does not enqueue photo job when printer has no camera' do
    @printer.update!(camera_url: nil)
    payloads = {
      status: { 'printer' => { 'state' => 'PRINTING' } },
      job: { 'id' => 'pl-555', 'file' => { 'display_name' => 'thing.gcode' } }
    }

    assert_no_enqueued_jobs only: CaptureEventPhotoJob do
      PrinterPoller.new(@printer,
                        prusalink: stub_prusalink(payloads),
                        home_assistant: stub_home_assistant).poll!
    end
  end

  test 'is a no-op when prusalink_key is missing' do
    @printer.update!(prusalink_key: nil)
    prusalink = Minitest::Mock.new # nothing should be called

    assert_no_difference -> { Job.count } do
      PrinterPoller.new(@printer, prusalink: prusalink, home_assistant: stub_home_assistant).poll!
    end
  end

  test 'finalizes active jobs and marks printer idle when PrusaLink reports IDLE' do
    job = @printer.jobs.create!(filename: 'thing.gcode', status: 'printing',
                                prusalink_job_id: 'pl-555', started_at: 5.minutes.ago)
    job.events.create!(event_type: 'started', to_status: 'printing', occurred_at: 5.minutes.ago)

    ambient_sensor = Setting.default_ambient_sensor
    payloads = {
      status: { 'printer' => { 'state' => 'IDLE', 'temp_bed' => 25.0 } },
      job: nil
    }
    ha = stub_home_assistant(temperatures: { ambient_sensor => '21.5' })

    assert_difference -> { JobEvent.count } => 1 do
      assert_no_difference -> { Job.count } do
        PrinterPoller.new(@printer, prusalink: stub_prusalink(payloads), home_assistant: ha).poll!
      end
    end

    job.reload
    @printer.reload

    assert_equal 'finished', job.status
    assert_not_nil job.ended_at
    assert_equal 'finished', job.events.recent.first.event_type
    assert_equal 'idle', @printer.operational_state
    assert_in_delta 21.5, @printer.ambient_temp.to_f
    assert_not_nil @printer.environment_updated_at
    assert_nil @printer.current_job
  end

  test 'updates ambient temperature on idle poll without creating a job' do
    ambient_sensor = Setting.default_ambient_sensor
    payloads = {
      status: { 'printer' => { 'state' => 'READY' } },
      job: nil
    }
    ha = stub_home_assistant(temperatures: { ambient_sensor => '19.0' })

    assert_no_difference -> { Job.count } do
      PrinterPoller.new(@printer, prusalink: stub_prusalink(payloads), home_assistant: ha).poll!
    end

    @printer.reload

    assert_equal 'idle', @printer.operational_state
    assert_in_delta 19.0, @printer.ambient_temp.to_f
  end

  test 'updates printer environment while printing' do
    ambient_sensor = Setting.default_ambient_sensor
    payloads = {
      status: { 'printer' => { 'state' => 'PRINTING', 'temp_bed' => 60.0, 'temp_nozzle' => 215.0 } },
      job: { 'id' => 'pl-555', 'file' => { 'display_name' => 'thing.gcode' } }
    }
    ha = stub_home_assistant(temperatures: { ambient_sensor => '22.0' })

    PrinterPoller.new(@printer, prusalink: stub_prusalink(payloads), home_assistant: ha).poll!

    @printer.reload

    assert_equal 'printing', @printer.operational_state
    assert_in_delta 22.0, @printer.ambient_temp.to_f
  end

  private

  def stub_prusalink(payloads)
    obj = Object.new
    obj.define_singleton_method(:status) { payloads[:status] }
    obj.define_singleton_method(:job)    { payloads[:job] }
    obj
  end

  def stub_home_assistant(temperatures: {})
    obj = Object.new
    obj.define_singleton_method(:configured?) { true }
    obj.define_singleton_method(:numeric_state) { |entity_id| temperatures[entity_id] }
    obj
  end
end
