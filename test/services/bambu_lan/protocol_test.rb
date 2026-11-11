require 'test_helper'
require 'zip'

class BambuLanProtocolTest < ActiveSupport::TestCase
  test 'maps print states onto the Prusa vocabulary' do
    assert_equal 'IDLE', state('IDLE')
    assert_equal 'PRINTING', state('RUNNING')
    assert_equal 'PRINTING', state('PREPARE')
    assert_equal 'PAUSED', state('PAUSE')
    assert_equal 'FINISHED', state('FINISH')
    assert_equal 'STOPPED', state('FAILED')
    assert_equal 'ERROR', state('FAILED', 'print_error' => 83_902_467)
    assert_equal 'ATTENTION', state('PAUSE', 'print_error' => 83_902_467)
    assert_equal 'PRINTING', state('RUNNING', 'print_error' => 83_902_467)
    assert_equal 'ATTENTION', state('RUNNING', 'hms' => [{ 'code' => '0300400000020001' }])
  end

  test 'describes a known print error and an HMS code' do
    message = BambuLan::ErrorDetail.message('gcode_state' => 'FAILED', 'print_error' => 83_902_467,
                                            'hms' => [{ 'code' => '0300400000020001' }])

    assert_match(/could not parse the file/, message)
    assert_match(/HMS 0300-4000-0002-0001/, message)
  end

  test 'picks the camera transport and chamber sensor from the model name' do
    assert_equal :rtsps, BambuLan::Models.camera('P2S')
    assert_equal :rtsps, BambuLan::Models.camera('X1 Carbon')
    assert_equal :jpeg, BambuLan::Models.camera('A1 mini')
    assert_equal :jpeg, BambuLan::Models.camera('P1S')
    assert_equal :auto, BambuLan::Models.camera('mystery')
    assert BambuLan::Models.chamber?('P2S')
    assert_not BambuLan::Models.chamber?('A1')
  end

  test 'strips a scheme and port off the printer host' do
    printer = printers(:bambu_p2s)
    printer.hostname = 'http://10.1.2.3:8883/status'

    assert_equal '10.1.2.3', BambuLan::Host.for(printer)
  end

  test 'reads filament weight, plate name, and thumbnail from a sliced 3mf' do
    archive = BambuLan::Archive.parse(sliced_3mf)

    assert_equal 'plate_1.gcode', archive.plate
    assert_in_delta 12.5, archive.grams
    assert_equal 2, archive.filament_count
    assert_equal 'PNGDATA', archive.png
  end

  test 'builds the jpeg camera auth packet and splits a framed image' do
    packet = BambuLan::JpegCamera.auth_packet(username: 'bblp', access_code: 'abcd1234')
    jpeg = "\xFF\xD8\xFF\xD9".b
    frame, rest = BambuLan::JpegCamera.extract_frame([jpeg.bytesize, 0, 1, 0].pack('V4') + jpeg + 'more'.b)

    assert_equal 80, packet.bytesize
    assert_equal 'bblp', packet.byteslice(16, 4)
    assert_equal 'abcd1234', packet.byteslice(48, 8)
    assert_equal jpeg, frame
    assert_equal 'more', rest
  end

  test 'keeps the access code out of the FTPS url' do
    runner = RecordingRunner.new
    BambuLan::Ftps.new(printers(:bambu_p2s), runner: runner).download('cache/benchy.gcode.3mf')

    assert_equal 'ftps://192.168.1.50:990/cache/benchy.gcode.3mf', runner.argv.last
    assert_not_includes runner.argv.last, 'abcd1234'
    assert_includes runner.config, 'user = "bblp:abcd1234"'
    assert_includes runner.config, 'ssl-reqd'
  end

  test 'rejects an FTPS path that climbs out of the printer storage' do
    ftps = BambuLan::Ftps.new(printers(:bambu_p2s), runner: RecordingRunner.new)

    assert_raises(BambuLan::Error) { ftps.download('../etc/passwd') }
  end

  test 'uses the external spool when no AMS tray is selected' do
    fields = BambuLan::ProjectFile.fields(filename: 'part.3mf', archive: one_filament,
                                          report: { 'print' => { 'gcode_state' => 'IDLE' } })

    assert_equal 'Metadata/plate_1.gcode', fields['param']
    assert_equal 'ftp:///cache/part.3mf', fields['url']
    assert_not fields['use_ams']
  end

  test 'maps one filament to the selected AMS tray' do
    report = { 'print' => ams_print('0', [%w[0 PLA]]) }
    fields = BambuLan::ProjectFile.fields(filename: 'part.3mf', archive: one_filament, report: report)

    assert fields['use_ams']
    assert_equal [0], fields['ams_mapping']
  end

  test 'refuses a multi-color file when the AMS does not have enough filament' do
    report = { 'print' => ams_print('0', [%w[0 PLA]]) }

    error = assert_raises(BambuLan::Error) do
      BambuLan::ProjectFile.fields(filename: 'part.3mf', archive: BambuLan::Archive.parse(sliced_3mf), report: report)
    end

    assert_match(/needs 2 filaments/, error.message)
  end

  test 'prefers a full status snapshot over a delta' do
    session = ScriptedSession.new([
                                    { 'print' => { 'gcode_state' => 'RUNNING', 'msg' => 1,
                                                   'mc_percent' => 1 } }.to_json,
                                    { 'print' => { 'gcode_state' => 'RUNNING', 'msg' => 0,
                                                   'bed_temper' => 60 } }.to_json
                                  ])
    report = BambuLan::Mqtt.new(printers(:bambu_p2s), session: session).fetch_report

    assert_equal 60, report.dig('print', 'bed_temper')
    assert_includes session.published.first, 'pushall'
  end

  test 'sends a pause command and waits for the matching acknowledgement' do
    ack = { 'print' => { 'sequence_id' => '1', 'result' => 'success' } }.to_json
    session = ScriptedSession.new([ack])

    assert BambuLan::Mqtt.new(printers(:bambu_p2s), session: session).command('print', 'pause')

    body = JSON.parse(session.published.first)

    assert_equal 'pause', body.dig('print', 'command')
    assert_equal '1', body.dig('print', 'sequence_id')
  end

  test 'reads P2S nozzle and chamber temperatures from the device object' do
    report = {
      'print' => { 'gcode_state' => 'RUNNING', 'bed_temper' => 60 },
      'device' => { 'nozzle' => [{ 'temp' => 220, 'diameter' => 0.4 }], 'ctc' => { 'info' => { 'temp' => 40 } } }
    }

    tool = BambuLan::Tools.entries(report, material: 'PLA').first

    assert_in_delta 220.0, tool['temp']
    assert_in_delta 0.4, tool['nozzle_diameter']
    assert_equal 'PLA', tool['material']
    assert_in_delta 40.0, BambuLan::Tools.chamber(report, model: 'P2S')
    assert_nil BambuLan::Tools.chamber(report, model: 'A1')
  end

  test 'scrubs the access code out of an error' do
    assert_equal 'rtsps://bblp:[redacted]@printer failed',
                 BambuLan::Secrets.scrub('rtsps://bblp:abcd1234@printer failed', 'abcd1234')
  end

  private

  def state(gcode_state, extra = {})
    BambuLan::StateMapper.prusa_state({ 'gcode_state' => gcode_state }.merge(extra))
  end

  def ams_print(tray_now, trays)
    {
      'gcode_state' => 'IDLE',
      'ams' => {
        'tray_now' => tray_now,
        'ams' => [{ 'id' => '0', 'tray' => trays.map { |id, type| { 'id' => id, 'tray_type' => type } } }]
      }
    }
  end

  def one_filament
    BambuLan::Archive::Result.new(plate: 'plate_1.gcode', grams: 10.5, png: nil, filament_count: 1)
  end

  def sliced_3mf
    xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <config>
        <plate>
          <metadata key="index" value="1"/>
          <filament id="1" type="PLA" used_g="10.0"/>
          <filament id="2" type="PETG" used_g="2.5"/>
        </plate>
      </config>
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

  class RecordingRunner
    attr_reader :argv, :config

    def run(argv, timeout:, binary: true)
      @argv = argv
      @timeout = timeout
      @binary = binary
      @config = File.read(argv[argv.index('--config') + 1])
      'bytes'
    end
  end

  class ScriptedSession
    attr_reader :published

    def initialize(payloads)
      @payloads = payloads.dup
      @published = []
    end

    def subscribe(*); end

    def publish(_topic, payload)
      @published << payload
    end

    def next_payload(*)
      @payloads.shift
    end

    def disconnect; end
  end
end
