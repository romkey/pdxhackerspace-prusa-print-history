require 'test_helper'

module PrusaConnect
  class ErrorDetailTest < ActiveSupport::TestCase
    FakeClient = Struct.new(:printer_payload, :job_list, :note_list) do
      def configured? = true
      def printer(_uuid) = printer_payload
      def jobs(_uuid) = job_list
      def notifications(**) = note_list
    end

    setup do
      @printer = printers(:prusa_xl)
      @printer.update!(prusa_connect_uuid: 'uuid-1')
      @now = Time.current
    end

    test 'combines state reason, job failure tags and notifications' do
      client = FakeClient.new(
        { 'printer_state' => 'ERROR', 'state_reason' => 'Heatbreak thermistor disconnected' },
        [{ 'state' => 'FIN_ERROR', 'end' => @now.to_i, 'reason' => { 'tag' => %w[CLOGGED_NOZZLE IGNORED] } }],
        [{ 'text' => 'Print failed', 'created' => @now.to_i, 'data' => { 'printer_uuid' => 'uuid-1' } },
         { 'text' => 'Other printer', 'created' => @now.to_i, 'data' => { 'printer_uuid' => 'uuid-2' } }]
      )

      result = ErrorDetail.fetch(@printer, since: @now - 1.minute, client: client)

      expected = 'Heatbreak thermistor disconnected — Marked in Connect: clogged nozzle — Print failed'

      assert_equal expected, result.message
    end

    test 'returns nil when Connect has nothing to add' do
      client = FakeClient.new({ 'printer_state' => 'PRINTING' }, [], [])

      assert_nil ErrorDetail.fetch(@printer, since: @now, client: client)
    end

    test 'returns nil without a printer uuid' do
      @printer.update!(prusa_connect_uuid: nil)

      assert_nil ErrorDetail.fetch(@printer, since: @now, client: FakeClient.new({}, [], []))
    end
  end
end
