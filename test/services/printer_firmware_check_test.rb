require 'test_helper'

class PrinterFirmwareCheckTest < ActiveSupport::TestCase
  FakePrusaLink = Struct.new(:payload) do
    def version = payload.is_a?(Exception) ? raise(payload) : payload
  end
  FakeBambu = Struct.new(:firmware_versions)
  FakeConnect = Struct.new(:payload) do
    def printer(_uuid) = payload
  end

  setup { @printer = printers(:prusa_mini).tap { |p| p.update!(prusalink_key: 'k') } }

  test 'first reading is logged as the initial reading' do
    assert_difference -> { @printer.service_entries.repairs.count }, 1 do
      PrinterFirmwareCheck.call(@printer, client: FakePrusaLink.new({ 'firmware' => '6.3.3-7541' }))
    end
    assert_equal '6.3.3-7541', @printer.reload.firmware_version
    entry = @printer.service_entries.repairs.recent.first

    assert_match(/initial reading/, entry.summary)
    assert_nil entry.user
  end

  test 'unchanged version logs nothing, change logs a repair' do
    @printer.update!(firmware_version: '6.3.3')
    assert_no_difference -> { ServiceEntry.count } do
      PrinterFirmwareCheck.call(@printer, client: FakePrusaLink.new({ 'firmware' => '6.3.3' }))
    end
    PrinterFirmwareCheck.call(@printer, client: FakePrusaLink.new({ 'firmware' => '6.4.0' }))

    assert_equal 'Printer firmware updated: 6.3.3 → 6.4.0', @printer.service_entries.repairs.recent.first.summary
    assert_equal '6.4.0', @printer.reload.firmware_version
  end

  test 'a failed read changes nothing' do
    assert_no_difference -> { ServiceEntry.count } do
      PrinterFirmwareCheck.call(@printer, client: FakePrusaLink.new(PrusaLink::Error.new('down')))
    end
    assert_nil @printer.reload.firmware_version
  end

  test 'reads Bambu firmware' do
    bambu = printers(:bambu_p2s)
    PrinterFirmwareCheck.call(bambu, client: FakeBambu.new({ 'printer' => '01.08.02.00', 'ams/0' => '00.00.06.49' }))

    assert_equal '01.08.02.00', bambu.reload.firmware_version
  end

  test 'falls back to Prusa Connect' do
    @printer.update!(prusalink_key: nil, prusa_connect_uuid: 'abc')
    @printer.define_singleton_method(:prusa_connect_api?) { true }
    PrinterFirmwareCheck.call(@printer, connect: FakeConnect.new({ 'firmware' => '5.1.2' }))

    assert_equal '5.1.2', @printer.reload.firmware_version
  end

  test 'Bambu components log one grouped initial entry, then one entry per change' do
    bambu = printers(:bambu_p2s)
    PrinterFirmwareCheck.call(bambu, client: FakeBambu.new({ 'printer' => '1.0', 'ams/0' => 'a1' }))

    assert_equal 1, bambu.service_entries.repairs.count
    assert_includes bambu.service_entries.repairs.first.details, 'AMS 0: a1'

    PrinterFirmwareCheck.call(bambu, client: FakeBambu.new({ 'printer' => '1.0', 'ams/0' => 'a2' }))

    assert_equal 'AMS 0 firmware updated: a1 → a2', bambu.service_entries.repairs.recent.first.summary
    assert_equal 2, bambu.service_entries.repairs.count
  end
end
