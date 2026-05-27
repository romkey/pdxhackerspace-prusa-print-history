require 'test_helper'

class JobTelemetryChartsTest < ActiveSupport::TestCase
  test 'builds multi-series chart payload from readings' do
    job = jobs(:active_xl)
    readings = job.telemetry_readings.ordered.to_a
    series = JobTelemetryCharts.series_for(readings, job: job)
    bed = series.find { |entry| entry[:name] == 'Bed' }

    assert_instance_of Array, series
    assert(series.all? { |entry| entry.key?(:name) && entry.key?(:data) && entry.key?(:color) })
    assert_includes series.pluck(:name), 'Bed'
    assert_includes series.pluck(:name), 'Enclosure'
    assert_includes series.pluck(:name), 'Ambient'
    assert_includes series.pluck(:name), 'T0'
    assert_equal readings.size, bed[:data].size
    assert_equal readings.first.bed_temp.to_f, bed[:data].first.last
    assert_equal '#e07a5f', bed[:color]
  end

  test 'returns empty array without readings' do
    assert_empty JobTelemetryCharts.series_for([])
  end

  test 'limits active job chart window to start and now' do
    job = jobs(:active_xl)
    options = JobTelemetryCharts.chart_options(job)

    assert_equal job.started_at, options[:xmin]
    assert_in_delta Time.current.to_i, options[:xmax].to_i, 2
  end

  test 'limits finished job chart window to start and end' do
    job = jobs(:finished)
    options = JobTelemetryCharts.chart_options(job)

    assert_equal job.started_at, options[:xmin]
    assert_equal job.ended_at, options[:xmax]
  end

  test 'returns no chart options without a job start time' do
    job = jobs(:finished)
    job.update!(started_at: nil)

    assert_empty JobTelemetryCharts.chart_options(job)
  end

  test 'filters readings outside the job window' do
    job = jobs(:active_xl)
    job.update!(started_at: 10.minutes.ago, ended_at: 2.minutes.ago)
    readings = job.telemetry_readings.ordered.to_a
    filtered = JobTelemetryCharts.filter_readings(readings, job)

    assert(filtered.all? { |reading| reading.recorded_at.between?(job.started_at, job.ended_at) })
  end
end
