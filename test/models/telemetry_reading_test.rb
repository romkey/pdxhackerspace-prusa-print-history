require 'test_helper'

class TelemetryReadingTest < ActiveSupport::TestCase
  test 'tool_temp accepts integer or string keys' do
    reading = telemetry_readings(:active_xl_one)

    assert_in_delta(215.0, reading.tool_temp(0).to_f)
    assert_in_delta(235.0, reading.tool_temp('1').to_f)
  end

  test 'ordered scope is chronological' do
    ids = jobs(:active_xl).telemetry_readings.ordered.pluck(:id)

    assert_equal [telemetry_readings(:active_xl_one).id, telemetry_readings(:active_xl_two).id], ids
  end

  test 'requires recorded_at' do
    record = TelemetryReading.new(job: jobs(:active_xl))

    assert_not record.valid?
    assert_includes record.errors[:recorded_at], "can't be blank"
  end
end
