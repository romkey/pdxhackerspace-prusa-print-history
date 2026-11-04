require 'test_helper'

class PrinterControlTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :calls, :job

    def initialize(job)
      @job = job
      @calls = []
    end

    def status = { 'printer' => { 'state' => 'IDLE' } }
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
end
