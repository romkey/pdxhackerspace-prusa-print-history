require 'test_helper'

class PrusaLinkPrintMetadataTest < ActiveSupport::TestCase
  test 'reads snake_case gcode metadata for multiple tools' do
    meta = {
      'filament_type' => 'PLA',
      'nozzle_diameter' => 0.4,
      'nozzle_high_flow' => 0,
      'filament_type per tool' => %w[PLA PETG],
      'nozzle_diameter per tool' => [0.4, 0.6]
    }

    entries = PrusaLink::PrintMetadata.tool_entries(
      status_payload: {},
      job_payload: { 'file' => { 'meta' => meta } }
    )

    assert_equal 2, entries.size
    assert_equal 'PLA', entries[0].material
    assert_in_delta 0.4, entries[0].nozzle_size_mm.to_f
    assert_equal 'PETG', entries[1].material
    assert_in_delta 0.6, entries[1].nozzle_size_mm.to_f
  end

  test 'reads legacy spaced metadata keys' do
    meta = {
      'filament type' => 'PLA',
      'nozzle diameter' => '0.4',
      'filament type 2' => 'PETG',
      'nozzle diameter 2' => '0.6'
    }

    entries = PrusaLink::PrintMetadata.tool_entries(
      status_payload: {},
      job_payload: { 'file' => { 'meta' => meta } }
    )

    assert_equal 'PLA', entries[0].material
    assert_equal 'PETG', entries[1].material
  end

  test 'merges idle legacy material and info nozzle for tool zero' do
    entries = PrusaLink::PrintMetadata.tool_entries(
      status_payload: { 'printer' => { 'state' => 'IDLE' } },
      info_payload: { 'nozzle_diameter' => 0.5 },
      legacy_payload: { 'telemetry' => { 'material' => 'ASA' } }
    )

    assert_equal 1, entries.size
    assert_equal 'ASA', entries[0].material
    assert_in_delta 0.5, entries[0].nozzle_size_mm.to_f
  end

  test 'reads material from status tools when present' do
    entries = PrusaLink::PrintMetadata.tool_entries(
      status_payload: {
        'tools' => [
          { 'index' => 0, 'material' => 'PLA', 'nozzle_diameter' => 0.4 },
          { 'index' => 1, 'material' => 'PETG', 'nozzle_diameter' => 0.6, 'high_flow' => true }
        ]
      }
    )

    assert_equal 'PLA', entries[0].material
    assert_equal 'PETG', entries[1].material
    assert entries[1].high_flow
  end

  test 'reads per-tool info endpoint tools hash' do
    entries = PrusaLink::PrintMetadata.tool_entries(
      status_payload: {},
      info_payload: {
        'tools' => {
          '1' => { 'nozzle_diameter' => 0.4, 'material' => 'PLA', 'high_flow' => false },
          '2' => { 'nozzle_diameter' => 0.6, 'material' => 'PETG', 'high_flow' => true }
        }
      }
    )

    assert_equal 2, entries.size
    assert_equal 'PLA', entries[0].material
    assert_equal 'PETG', entries[1].material
    assert entries[1].high_flow
  end

  test 'reads bracket suffix metadata keys' do
    meta = {
      'filament_type[0]' => 'PLA',
      'filament_type[1]' => 'PETG',
      'nozzle_diameter[0]' => 0.4,
      'nozzle_diameter[1]' => 0.6
    }

    entries = PrusaLink::PrintMetadata.tool_entries(
      status_payload: {},
      job_payload: { 'file' => { 'meta' => meta } }
    )

    assert_equal 'PLA', entries[0].material
    assert_equal 'PETG', entries[1].material
  end

  test 'reads comma-separated printing_filament_types list' do
    entries = PrusaLink::PrintMetadata.tool_entries(
      status_payload: {},
      job_payload: {
        'file' => {
          'meta' => { 'printing_filament_types' => 'PLA,PETG' }
        }
      }
    )

    assert_equal 'PLA', entries[0].material
    assert_equal 'PETG', entries[1].material
  end
end
