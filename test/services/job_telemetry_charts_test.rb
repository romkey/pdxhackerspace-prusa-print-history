require 'test_helper'

class JobTelemetryChartsTest < ActiveSupport::TestCase
  test 'builds temperature series from readings' do
    job = jobs(:active_xl)
    readings = job.telemetry_readings.ordered.to_a
    series = JobTelemetryCharts.series_for(readings)

    assert_includes series.keys, 'Bed'
    assert_includes series.keys, 'T0'
    assert_equal readings.size, series['Bed'].size
    assert_equal readings.first.bed_temp.to_f, series['Bed'].first.last
  end

  test 'returns empty hash without readings' do
    assert_empty JobTelemetryCharts.series_for([])
  end
end
