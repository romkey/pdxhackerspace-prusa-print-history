require 'test_helper'

class ToolTest < ActiveSupport::TestCase
  test 'tool_index is unique per job' do
    duplicate = Tool.new(job: jobs(:active_xl), tool_index: 0, nozzle_size_mm: 0.40)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:tool_index], 'has already been taken'
  end

  test 'nozzle_size_mm must be positive' do
    bad = Tool.new(job: jobs(:active_xl), tool_index: 9, nozzle_size_mm: 0)

    assert_not bad.valid?
    assert_includes bad.errors[:nozzle_size_mm], 'must be greater than 0'
  end

  test 'label combines tool number, nozzle, HF flag, material' do
    label = tools(:active_xl_tool_b).label

    assert_match(/T1/,   label)
    assert_match(/0.6/,  label)
    assert_match(/HF/,   label)
    assert_match(/PETG/, label)
  end
end
