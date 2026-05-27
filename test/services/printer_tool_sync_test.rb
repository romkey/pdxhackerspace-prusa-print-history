require 'test_helper'

class PrinterToolSyncTest < ActiveSupport::TestCase
  setup do
    @job = jobs(:active_xl)
  end

  test 'creates tools from parsed metadata entries' do
    @job.tools.delete_all
    entries = PrusaLink::PrintMetadata.tool_entries(
      status_payload: {
        'tools' => [{ 'index' => 0, 'temp' => 215.0 }, { 'index' => 1, 'temp' => 235.0 }]
      },
      job_payload: {
        'file' => {
          'meta' => {
            'nozzle_diameter' => 0.4,
            'filament_type' => 'PLA',
            'nozzle_diameter per tool' => [0.4, 0.6],
            'filament_type per tool' => %w[PLA PETG]
          }
        }
      }
    )

    PrinterToolSync.sync!(@job, entries)

    assert_equal 2, @job.tools.count
    assert_in_delta 0.4, @job.tools.find_by!(tool_index: 0).nozzle_size_mm.to_f
    assert_equal 'PLA', @job.tools.find_by!(tool_index: 0).material
    assert_in_delta 0.6, @job.tools.find_by!(tool_index: 1).nozzle_size_mm.to_f
    assert_equal 'PETG', @job.tools.find_by!(tool_index: 1).material
  end
end
