require 'test_helper'

class PrinterControlTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :calls, :job
    attr_writer :state

    def initialize(job)
      @job = job
      @calls = []
    end

    def status = { 'printer' => { 'state' => @state || 'IDLE' } }
    def upload_file(io, filename:, size:, **) = @calls << [:upload, filename, size, io.read]
    def pause_job(id) = @calls << [:pause, id]
    def resume_job(id) = @calls << [:resume, id]
    def stop_job(id) = @calls << [:stop, id]
  end

  setup do
    @printer = printers(:prusa_xl)
    @printer.update!(prusalink_key: 'k')
  end

  test 'pauses a printing job' do
    client = FakeClient.new({ 'id' => 5, 'state' => 'PRINTING' })
    PrinterControl.new(@printer, client: client).pause

    assert_equal [[:pause, 5]], client.calls
  end

  test 'refuses to resume a job that is not paused' do
    client = FakeClient.new({ 'id' => 5, 'state' => 'PRINTING' })

    assert_raises(PrinterControl::NotAllowed) { PrinterControl.new(@printer, client: client).resume }
    assert_empty client.calls
  end

  test 'refuses when there is no job' do
    client = FakeClient.new(nil)

    assert_raises(PrinterControl::NotAllowed) { PrinterControl.new(@printer, client: client).stop }
  end

  test 'stops a paused job' do
    client = FakeClient.new({ 'id' => 5, 'state' => 'PAUSED' })
    PrinterControl.new(@printer, client: client).stop

    assert_equal [[:stop, 5]], client.calls
  end

  def gcode_upload(name = 'part.gcode', body = 'G28')
    file = Tempfile.new(['up', '.gcode'])
    file.write(body)
    file.flush
    (@tempfiles ||= []) << file
    Struct.new(:original_filename, :tempfile).new(name, file)
  end

  test 'submit uploads the file to an idle printer' do
    client = FakeClient.new(nil)

    assert_equal 'part.gcode', PrinterControl.new(@printer, client: client).submit(gcode_upload)
    assert_equal [[:upload, 'part.gcode', 3, 'G28']], client.calls
  end

  test 'submit strips directories and unsafe characters from the filename' do
    client = FakeClient.new(nil)
    PrinterControl.new(@printer, client: client).submit(gcode_upload('../../etc/my part$.bgcode'))

    assert_equal 'my part_.bgcode', client.calls.first[1]
  end

  test 'submit rejects non-gcode files and missing files' do
    client = FakeClient.new(nil)
    control = PrinterControl.new(@printer, client: client)

    assert_raises(PrinterControl::NotAllowed) { control.submit(gcode_upload('evil.sh')) }
    assert_raises(PrinterControl::NotAllowed) { control.submit(nil) }
    assert_empty client.calls
  end

  test 'submit refuses while the printer is busy' do
    client = FakeClient.new(nil)
    client.state = 'PRINTING'

    assert_raises(PrinterControl::NotAllowed) { PrinterControl.new(@printer, client: client).submit(gcode_upload) }
    assert_empty client.calls
  end
end
