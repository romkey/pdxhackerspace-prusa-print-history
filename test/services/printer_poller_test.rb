require 'test_helper'

class PrinterPollerTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @printer = printers(:prusa_mini) # no jobs in fixtures
    @printer.update!(prusalink_key: 'key', camera_url: 'http://printer/snapshot.jpg')
    PrusaLink::Client.new(@printer)
  end

  test 'creates a job, telemetry reading, and started event on first poll' do
    payloads = {
      status: { 'printer' => { 'state' => 'PRINTING', 'temp_bed' => 60.0, 'temp_nozzle' => 215.0 } },
      job: {
        'id' => 'pl-555',
        'file' => {
          'display_name' => 'thing.gcode',
          'refs' => { 'thumbnail' => '/api/thumbnails/local/thing.gcode.orig.png' }
        }
      }
    }

    prusalink = stub_prusalink(payloads)
    prusalink.define_singleton_method(:download) { |_path| 'PNG-BYTES' }
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
    assert job.preview_image.attached?
  end

  test 'creates job and telemetry from status payload when job endpoint is empty' do
    payloads = {
      status: {
        'printer' => { 'state' => 'PRINTING', 'temp_bed' => 60.0, 'temp_nozzle' => 215.0 },
        'job' => { 'id' => 420, 'progress' => 42.0 }
      },
      job: nil
    }

    prusalink = stub_prusalink(payloads)
    ha = stub_home_assistant

    assert_difference -> { Job.count } => 1,
                      -> { TelemetryReading.count } => 1 do
      PrinterPoller.new(@printer, prusalink: prusalink, home_assistant: ha).poll!
    end

    job = Job.find_by!(prusalink_job_id: '420')

    assert_equal 'printing', job.status
    assert_equal 'Print job 420', job.filename
    assert_in_delta 60.0, job.telemetry_readings.last.bed_temp.to_f
    assert_in_delta 215.0, job.telemetry_readings.last.tool_temp(0).to_f
  end

  test 'maps BUSY printer state to an active printing job' do
    payloads = {
      status: {
        'printer' => { 'state' => 'BUSY', 'temp_bed' => 55.0, 'temp_nozzle' => 200.0 },
        'job' => { 'id' => 777, 'progress' => 0.0 }
      },
      job: nil
    }

    PrinterPoller.new(@printer, prusalink: stub_prusalink(payloads), home_assistant: stub_home_assistant).poll!

    job = Job.find_by!(prusalink_job_id: '777')

    assert_equal 'printing', job.status
    assert job.telemetry_readings.any?
  end

  test 'records a status_change event when status flips' do
    job = @printer.jobs.create!(filename: 'thing.gcode', status: 'printing',
                                prusalink_job_id: 'pl-555', started_at: 5.minutes.ago,
                                owner: users(:viewer))
    job.events.create!(event_type: 'started', to_status: 'printing', occurred_at: 5.minutes.ago)

    payloads = {
      status: { 'printer' => { 'state' => 'ATTENTION' } },
      job: { 'id' => 'pl-555', 'file' => { 'display_name' => 'thing.gcode' } }
    }
    prusalink = stub_prusalink(payloads)
    ha = stub_home_assistant

    assert_enqueued_with(job: CaptureEventPhotoJob) do
      assert_enqueued_with(job: JobAttentionNotificationJob, args: [job.id]) do
        PrinterPoller.new(@printer, prusalink: prusalink, home_assistant: ha).poll!
      end
    end

    assert_equal 'attention', job.reload.status
    assert_equal 'attention', job.events.recent.first.event_type
  end

  test 'does not notify owner when unclaimed print needs attention' do
    job = @printer.jobs.create!(filename: 'thing.gcode', status: 'printing',
                                prusalink_job_id: 'pl-555', started_at: 5.minutes.ago)
    job.events.create!(event_type: 'started', to_status: 'printing', occurred_at: 5.minutes.ago)

    payloads = {
      status: { 'printer' => { 'state' => 'ATTENTION' } },
      job: { 'id' => 'pl-555', 'file' => { 'display_name' => 'thing.gcode' } }
    }

    assert_no_enqueued_jobs only: JobAttentionNotificationJob do
      PrinterPoller.new(@printer, prusalink: stub_prusalink(payloads), home_assistant: stub_home_assistant).poll!
    end
  end

  test 'finalizes job on finished status' do
    job = @printer.jobs.create!(filename: 'thing.gcode', status: 'printing',
                                prusalink_job_id: 'pl-555', started_at: 1.hour.ago,
                                owner: users(:viewer))
    job.events.create!(event_type: 'started', to_status: 'printing', occurred_at: 1.hour.ago)

    payloads = {
      status: { 'printer' => { 'state' => 'FINISHED' } },
      job: { 'id' => 'pl-555', 'file' => { 'display_name' => 'thing.gcode' }, 'time_printing' => 3600 }
    }
    prusalink = stub_prusalink(payloads)

    assert_enqueued_with(job: JobFinishedNotificationJob, args: [job.id]) do
      PrinterPoller.new(@printer, prusalink: prusalink, home_assistant: stub_home_assistant).poll!
    end

    job.reload

    assert_equal 'finished', job.status
    assert_not_nil job.ended_at
    assert_equal 3600, job.total_duration_seconds
    assert_equal 'finished', job.events.recent.first.event_type
  end

  test 'does not enqueue photo job when printer has no camera configured' do
    @printer.update!(camera_url: nil, prusalink_key: nil)
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
    assert @printer.prusalink_reachable
  end

  test 'converts fahrenheit ambient temperature from Home Assistant to celsius' do
    ambient_sensor = Setting.default_ambient_sensor
    payloads = {
      status: { 'printer' => { 'state' => 'READY' } },
      job: nil
    }
    ha = stub_home_assistant(temperatures: { ambient_sensor => { value: '70', unit: '°F' } })

    PrinterPoller.new(@printer, prusalink: stub_prusalink(payloads), home_assistant: ha).poll!

    @printer.reload

    assert_in_delta 21.11, @printer.ambient_temp.to_f, 0.01
  end

  test 'marks PrusaLink unreachable when polling fails' do
    PrusaLink::Client.new(@printer)

    prusalink = Object.new
    prusalink.define_singleton_method(:status) { raise PrusaLink::Error, 'connection refused' }

    PrinterPoller.new(@printer, prusalink: prusalink, home_assistant: stub_home_assistant).poll!

    @printer.reload

    assert_not @printer.prusalink_reachable
    assert_not_nil @printer.prusalink_checked_at
  end

  test 'finalizes active jobs when PrusaLink reports FINISHED without a job payload' do
    job = @printer.jobs.create!(filename: 'thing.gcode', status: 'printing',
                                prusalink_job_id: 'pl-555', started_at: 20.minutes.ago)
    job.events.create!(event_type: 'started', to_status: 'printing', occurred_at: 20.minutes.ago)

    payloads = {
      status: { 'printer' => { 'state' => 'FINISHED', 'temp_bed' => 35.0, 'temp_nozzle' => 45.0 } },
      job: nil
    }

    assert_difference -> { TelemetryReading.count } => 1 do
      assert_difference -> { JobEvent.count } => 1 do
        PrinterPoller.new(@printer, prusalink: stub_prusalink(payloads), home_assistant: stub_home_assistant).poll!
      end
    end

    job.reload
    @printer.reload

    assert_equal 'finished', job.status
    assert_not_nil job.ended_at
    assert_equal 'idle', @printer.operational_state
    assert_nil @printer.current_job
  end

  test 'skips printer environment update when environment columns are absent' do
    without_environment_columns do
      payloads = {
        status: { 'printer' => { 'state' => 'READY' } },
        job: nil
      }

      assert_no_changes -> { @printer.reload.updated_at } do
        PrinterPoller.new(@printer, prusalink: stub_prusalink(payloads), home_assistant: stub_home_assistant).poll!
      end
    end
  end

  test 'syncs tool metadata from status and job payloads' do
    payloads = {
      status: {
        'printer' => { 'state' => 'PRINTING', 'temp_nozzle' => 215.0 },
        'tools' => [{ 'index' => 0, 'temp' => 215.0 }, { 'index' => 1, 'temp' => 235.0 }]
      },
      job: {
        'id' => 'pl-777',
        'file' => {
          'display_name' => 'multi.gcode',
          'meta' => {
            'nozzle_diameter' => 0.4,
            'filament_type' => 'PLA',
            'nozzle_diameter per tool' => [0.4, 0.6],
            'filament_type per tool' => %w[PLA PETG]
          }
        }
      },
      info: { 'nozzle_diameter' => 0.4 },
      legacy: nil
    }

    PrinterPoller.new(@printer, prusalink: stub_prusalink(payloads), home_assistant: stub_home_assistant).poll!

    job = Job.find_by!(prusalink_job_id: 'pl-777')

    assert_equal 2, job.tools.count
    assert_in_delta(0.4, job.tools.find_by!(tool_index: 0).nozzle_size_mm.to_f)
    assert_equal 'PLA', job.tools.find_by!(tool_index: 0).material
    assert_in_delta(0.6, job.tools.find_by!(tool_index: 1).nozzle_size_mm.to_f)
    assert_equal 'PETG', job.tools.find_by!(tool_index: 1).material
  end

  test 'syncs printer heads on idle poll from info and legacy endpoints' do
    @printer.printer_heads.delete_all
    payloads = {
      status: { 'printer' => { 'state' => 'IDLE' } },
      job: nil,
      info: { 'nozzle_diameter' => 0.5 },
      legacy: { 'telemetry' => { 'material' => 'PETG' } }
    }

    PrinterPoller.new(@printer, prusalink: stub_prusalink(payloads), home_assistant: stub_home_assistant).poll!

    head = @printer.printer_heads.find_by!(tool_index: 0)

    assert_in_delta 0.5, head.nozzle_size_mm.to_f
    assert_equal 'PETG', head.material
  end

  test 'syncs legacy telemetry material while printing on Core One style payload' do
    @printer.printer_heads.delete_all
    payloads = {
      status: { 'printer' => { 'state' => 'PRINTING', 'temp_nozzle' => 250.5 } },
      job: { 'id' => 'pl-core', 'file' => { 'display_name' => 'part.gcode' } },
      info: { 'nozzle_diameter' => 0.4 },
      legacy: {
        'telemetry' => { 'material' => 'PETG', 'temp-nozzle' => 250.5 },
        'state' => { 'flags' => { 'printing' => true } }
      }
    }

    PrinterPoller.new(@printer, prusalink: stub_prusalink(payloads), home_assistant: stub_home_assistant).poll!

    head = @printer.printer_heads.find_by!(tool_index: 0)
    job = Job.find_by!(prusalink_job_id: 'pl-core')

    assert_equal 'PETG', head.material
    assert_equal 'PETG', job.tools.find_by!(tool_index: 0).material
  end

  test 'syncs progress from status job telemetry when job endpoint is empty' do
    payloads = {
      status: {
        'printer' => { 'state' => 'PRINTING', 'temp_nozzle' => 250.0 },
        'job' => {
          'id' => 177,
          'progress' => 20.0,
          'time_remaining' => 6120,
          'time_printing' => 2472
        }
      },
      job: nil,
      info: { 'nozzle_diameter' => 0.4 },
      legacy: nil
    }

    freeze_time do
      PrinterPoller.new(@printer, prusalink: stub_prusalink(payloads), home_assistant: stub_home_assistant).poll!
    end

    job = Job.find_by!(prusalink_job_id: '177')

    assert_in_delta 20.0, job.progress_percent.to_f
    assert_equal 2472, job.time_printing_seconds
    assert_in_delta 6120, job.estimated_finish_at - Time.current, 2
  end

  test 'fetches file metadata when job payload omits meta block' do
    payloads = {
      status: { 'printer' => { 'state' => 'PRINTING', 'temp_nozzle' => 215.0 } },
      job: {
        'id' => 'pl-888',
        'file' => {
          'display_name' => 'part.gcode',
          'refs' => { 'download' => '/usb/part.gcode' }
        }
      },
      info: { 'nozzle_diameter' => 0.4 },
      legacy: nil,
      file_info: {
        '/usb/part.gcode' => {
          'meta' => {
            'filament_type' => 'ASA',
            'nozzle_diameter' => 0.4
          }
        }
      }
    }

    PrinterPoller.new(@printer, prusalink: stub_prusalink(payloads), home_assistant: stub_home_assistant).poll!

    head = @printer.printer_heads.find_by!(tool_index: 0)

    assert_equal 'ASA', head.material
  end

  private

  def without_environment_columns(&)
    columns = Printer.column_names - Printer::ENVIRONMENT_COLUMNS - Printer::CONNECTIVITY_COLUMNS
    Printer.stub(:column_names, columns, &)
  end

  def stub_prusalink(payloads)
    obj = Object.new
    obj.define_singleton_method(:status) { payloads[:status] }
    obj.define_singleton_method(:job)    { payloads[:job] }
    obj.define_singleton_method(:info)   { payloads.fetch(:info, {}) }
    obj.define_singleton_method(:legacy_printer) { payloads[:legacy] }
    obj.define_singleton_method(:file_info) do |path|
      payloads.fetch(:file_info, {})[path]
    end
    obj.define_singleton_method(:download) { |_path| nil }
    obj.define_singleton_method(:camera_snapshot) { nil }
    obj
  end

  def stub_home_assistant(temperatures: {})
    obj = Object.new
    obj.define_singleton_method(:configured?) { true }
    obj.define_singleton_method(:numeric_state) do |entity_id|
      entry = temperatures[entity_id]
      entry.is_a?(Hash) ? entry[:value] || entry['value'] : entry
    end
    obj.define_singleton_method(:temperature_celsius) do |entity_id|
      entry = temperatures[entity_id]
      case entry
      when Hash
        HomeAssistant::Temperature.to_celsius(
          entry[:value] || entry['value'],
          entry[:unit] || entry['unit_of_measurement']
        )
      when String, Numeric
        entry.to_f
      end
    end
    obj
  end
end
