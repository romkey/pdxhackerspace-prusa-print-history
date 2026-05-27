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
end
