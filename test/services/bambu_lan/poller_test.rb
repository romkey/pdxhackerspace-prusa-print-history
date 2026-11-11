require 'test_helper'
require 'zip'

class BambuLanPollerTest < ActiveJob::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @printer = printers(:bambu_p2s)
    FileUtils.rm_rf(Rails.root.join('tmp/bambu_cache'))
    FileUtils.rm_rf(Rails.root.join('tmp/bambu_previews'))
  end

  test 'a running report becomes a job with progress, filament, and a preview' do
    ftps = FakeFtps.new(sliced_3mf)

    travel_to Time.zone.local(2026, 11, 10, 12, 0, 0) do
      poll(running_report, ftps: ftps)
    end

    job = @printer.jobs.find_by!(prusalink_job_id: '99')

    assert_equal 'printing', job.status
    assert_equal 'Benchy', job.filename
    assert_in_delta 42.0, job.progress_percent
    expected_finish = Time.zone.local(2026, 11, 10, 12, 10, 0)

    assert_in_delta expected_finish.to_f, job.estimated_finish_at.to_f, 2
    assert_equal 'PLA', @printer.printer_heads.find_by!(tool_index: 0).material
    assert_in_delta 35.5, job.telemetry_readings.last.enclosure_temp
    assert_equal 'PNGDATA', job.preview_image.download
    assert_equal ['cache/benchy.gcode.3mf'], ftps.downloads
    assert_equal 'started', job.events.last.event_type
    assert_predicate @printer.reload, :prusalink_reachable
  end

  test 'finishing the same task records filament weight without downloading the 3mf again' do
    ftps = FakeFtps.new(sliced_3mf)
    poll(running_report, ftps: ftps)
    poll(running_report('gcode_state' => 'FINISH', 'mc_percent' => 100), ftps: ftps)

    job = @printer.jobs.find_by!(prusalink_job_id: '99')

    assert_equal 'finished', job.status
    assert_in_delta 10.5, job.total_filament_grams
    assert_predicate job, :terminal?
    assert_equal 1, ftps.downloads.size
  end

  test 'a paused print with an alert becomes an attention event' do
    poll(running_report)
    poll(running_report('gcode_state' => 'PAUSE', 'hms' => [{ 'code' => '0300400000020001' }]))

    event = @printer.jobs.find_by!(prusalink_job_id: '99').events.last

    assert_equal 'attention', event.to_status
    assert_match(/HMS 0300-4000-0002-0001/, event.message)
  end

  test 'a failed print with no error code is cancelled' do
    poll(running_report)
    poll(running_report('gcode_state' => 'FAILED', 'print_error' => 0))

    job = @printer.jobs.find_by!(prusalink_job_id: '99')

    assert_equal 'cancelled', job.status
    assert_equal 'The print was cancelled.', job.events.last.message
  end

  test 'a failed print with an error code is an error' do
    poll(running_report)
    poll(running_report('gcode_state' => 'FAILED', 'print_error' => 83_902_467))

    job = @printer.jobs.find_by!(prusalink_job_id: '99')

    assert_equal 'error', job.status
    assert_match(/could not parse the file/, job.events.last.message)
  end

  test 'an offline report marks the printer unreachable and leaves the job running' do
    poll(running_report)
    poll({ 'print' => { 'gcode_state' => 'OFFLINE' } })

    job = @printer.jobs.find_by!(prusalink_job_id: '99')

    assert_equal 'printing', job.status
    assert_not @printer.reload.prusalink_reachable
  end

  private

  def poll(report, ftps: FakeFtps.new(sliced_3mf))
    client = BambuLan::Client.new(@printer, mqtt: FakeMqtt.new(report), ftps: ftps, camera: FakeCamera.new)
    PrinterPoller.new(@printer, client: client, home_assistant: fake_ha).poll!
  end

  def running_report(extra = {})
    {
      'print' => {
        'gcode_state' => 'RUNNING',
        'mc_percent' => 42,
        'mc_remaining_time' => 10,
        'nozzle_temper' => 215.0,
        'bed_temper' => 60.0,
        'nozzle_diameter' => '0.4',
        'task_id' => '99',
        'subtask_name' => 'Benchy',
        'gcode_file' => 'cache/benchy.gcode.3mf',
        'gcode_start_time' => '1700000000',
        'ams' => {
          'tray_now' => '0',
          'ams' => [{ 'id' => '0', 'tray' => [{ 'id' => '0', 'tray_type' => 'PLA' }] }]
        }
      }.merge(extra),
      'device' => { 'ctc' => { 'info' => { 'temp' => 35.5 } } }
    }
  end

  def sliced_3mf
    xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <config><plate><metadata key="index" value="1"/>
      <filament id="1" type="PLA" used_g="10.5"/></plate></config>
    XML
    buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry('Metadata/plate_1.gcode')
      zip.write('G28')
      zip.put_next_entry('Metadata/plate_1.png')
      zip.write('PNGDATA')
      zip.put_next_entry('Metadata/slice_info.config')
      zip.write(xml)
    end
    buffer.string
  end

  def fake_ha
    obj = Object.new
    obj.define_singleton_method(:configured?) { true }
    obj.define_singleton_method(:numeric_state) { |_id| nil }
    obj.define_singleton_method(:temperature_celsius) { |_id| nil }
    obj
  end

  class FakeMqtt
    def initialize(report)
      @report = report
    end

    def fetch_report
      @report
    end

    def command(*)
      :ok
    end
  end

  class FakeFtps
    attr_reader :downloads

    def initialize(bytes)
      @bytes = bytes
      @downloads = []
    end

    def download(path)
      @downloads << path
      @bytes
    end

    def upload(*)
      :ok
    end
  end

  class FakeCamera
    def snapshot
      nil
    end
  end
end
