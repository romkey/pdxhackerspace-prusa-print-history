require 'test_helper'

class PrinterToolSyncTest < ActiveSupport::TestCase
  setup do
    @job = jobs(:active_xl)
  end

  test 'creates tools from status and job metadata' do
    @job.tools.delete_all
    status_payload = {
      'tools' => [{ 'index' => 0, 'temp' => 215.0 }, { 'index' => 1, 'temp' => 235.0 }]
    }
    job_payload = {
      'file' => {
        'meta' => {
          'nozzle diameter' => '0.4',
          'filament type' => 'PLA',
          'nozzle diameter 2' => '0.6',
          'filament type 2' => 'PETG'
        }
      }
    }

    PrinterToolSync.sync!(@job, status_payload, job_payload)

    assert_equal 2, @job.tools.count
    assert_in_delta 0.4, @job.tools.find_by!(tool_index: 0).nozzle_size_mm.to_f
    assert_equal 'PLA', @job.tools.find_by!(tool_index: 0).material
    assert_in_delta 0.6, @job.tools.find_by!(tool_index: 1).nozzle_size_mm.to_f
  end
end
