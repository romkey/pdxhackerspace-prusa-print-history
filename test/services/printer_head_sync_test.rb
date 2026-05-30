require 'test_helper'

class PrinterHeadSyncTest < ActiveSupport::TestCase
  test 'upserts printer heads without clearing existing material' do
    printer = printers(:prusa_mk4)
    printer.printer_heads.delete_all
    printer.printer_heads.create!(tool_index: 0, nozzle_size_mm: 0.4, material: 'PLA')

    entry = PrusaLink::PrintMetadata::ToolEntry.new(
      tool_index: 0,
      nozzle_size_mm: 0.5,
      material: nil,
      high_flow: false
    )

    PrinterHeadSync.sync!(printer, [entry])

    head = printer.printer_heads.find_by!(tool_index: 0)

    assert_in_delta 0.5, head.nozzle_size_mm.to_f
    assert_equal 'PLA', head.material
  end

  test 'records a printer event when filament material changes' do
    printer = printers(:prusa_mk4)
    printer.printer_heads.delete_all
    printer.printer_heads.create!(tool_index: 0, nozzle_size_mm: 0.4, material: 'PLA')

    entry = PrusaLink::PrintMetadata::ToolEntry.new(
      tool_index: 0,
      nozzle_size_mm: 0.4,
      material: 'PETG',
      high_flow: false
    )

    assert_difference -> { PrinterEvent.count } => 1 do
      PrinterHeadSync.sync!(printer, [entry])
    end

    event = printer.printer_events.last

    assert_equal 'filament_change', event.event_type
    assert_equal 0, event.tool_index
    assert_equal 'PLA', event.from_material
    assert_equal 'PETG', event.to_material
    assert_equal 'T0: PLA → PETG', event.message
  end

  test 'does not record a printer event when material is unchanged' do
    printer = printers(:prusa_mk4)
    printer.printer_heads.delete_all
    printer.printer_heads.create!(tool_index: 0, nozzle_size_mm: 0.4, material: 'PLA')

    entry = PrusaLink::PrintMetadata::ToolEntry.new(
      tool_index: 0,
      nozzle_size_mm: 0.4,
      material: 'PLA',
      high_flow: false
    )

    assert_no_difference -> { PrinterEvent.count } do
      PrinterHeadSync.sync!(printer, [entry])
    end
  end
end
