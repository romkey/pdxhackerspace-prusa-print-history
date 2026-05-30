require 'test_helper'

class PrintTimeReportTest < ActiveSupport::TestCase
  test 'by_printer includes all printers with period totals' do
    rows = PrintTimeReport.by_printer.index_by(&:label)

    assert_equal 7200, rows['Prusa XL'].week_seconds
    assert_equal 7200, rows['Prusa XL'].month_seconds
    assert_equal 7200, rows['Prusa XL'].all_seconds

    assert_equal 9000, rows['Prusa MK4'].week_seconds
    assert_equal 9000, rows['Prusa MK4'].all_seconds
    assert_equal 1800, rows['Prusa Mini'].all_seconds
    assert_equal 0, rows['Prusa Mini'].week_seconds
  end

  test 'by_user includes all users with claimed print totals and unclaimed time' do
    rows = PrintTimeReport.by_user.index_by(&:label)

    assert_equal 7200, rows['vieweruser'].all_seconds
    assert_equal 7200, rows['vieweruser'].week_seconds
    assert_equal 3600, rows['otherviewer'].all_seconds
    assert_equal 1800, rows['adminuser'].all_seconds
    assert_equal 0, rows['adminuser'].week_seconds
    assert_equal 5400, rows['Unclaimed'].all_seconds
    assert_equal 5400, rows['Unclaimed'].week_seconds
  end

  test 'by_user lists unclaimed row last with stable key' do
    rows = PrintTimeReport.by_user

    assert_equal 'Unclaimed', rows.last.label
    assert_equal 'unclaimed', rows.last.key
    assert_operator(rows.index { |row| row.label == 'Unclaimed' }, :>, rows.index { |row| row.label == 'otherviewer' })
  end

  test 'chart_series includes unclaimed print time when present' do
    rows = PrintTimeReport.by_user
    series = PrintTimeReport.chart_series(rows, limit: 10)
    all_time = series.find { |entry| entry[:name] == 'All time' }
    unclaimed = all_time[:data].find { |label, _| label == 'Unclaimed' }

    assert_in_delta 1.5, unclaimed.last, 0.01
  end

  test 'by_filament aggregates material time split across toolheads' do
    rows = PrintTimeReport.by_filament.index_by(&:label)

    assert_equal 10_800, rows['PLA'].all_seconds
    assert_equal 1800, rows['PETG'].all_seconds
  end

  test 'chart_series converts seconds to hours for chartkick multi-series format' do
    rows = PrintTimeReport.by_printer
    series = PrintTimeReport.chart_series(rows, limit: 2)

    assert_equal 'Last 7 days', series.first[:name]
    xl = series.first[:data].find { |label, _| label == 'Prusa XL' }

    assert_in_delta 2.0, xl.last, 0.01
    assert(series.all? { |entry| entry.key?(:name) && entry.key?(:data) })
  end
end
