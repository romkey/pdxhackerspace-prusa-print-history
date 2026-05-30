require 'test_helper'

class PrintTimeReportTest < ActiveSupport::TestCase
  test 'by_printer includes all printers with period totals' do
    rows = PrintTimeReport.by_printer.index_by(&:label)

    assert_equal 7200, rows['Prusa XL'].week_seconds
    assert_equal 7200, rows['Prusa XL'].month_seconds
    assert_equal 7200, rows['Prusa XL'].all_seconds

    assert_equal 3600, rows['Prusa MK4'].week_seconds
    assert_equal 1800, rows['Prusa Mini'].all_seconds
    assert_equal 0, rows['Prusa Mini'].week_seconds
  end

  test 'by_user includes all users with claimed print totals' do
    rows = PrintTimeReport.by_user.index_by(&:label)

    assert_equal 7200, rows['vieweruser'].all_seconds
    assert_equal 7200, rows['vieweruser'].week_seconds
    assert_equal 3600, rows['otherviewer'].all_seconds
    assert_equal 1800, rows['adminuser'].all_seconds
    assert_equal 0, rows['adminuser'].week_seconds
  end

  test 'by_filament aggregates material time split across toolheads' do
    rows = PrintTimeReport.by_filament.index_by(&:label)

    assert_equal 10_800, rows['PLA'].all_seconds
    assert_equal 1800, rows['PETG'].all_seconds
  end

  test 'chart_series converts seconds to hours for chartkick' do
    rows = PrintTimeReport.by_printer
    series = PrintTimeReport.chart_series(rows, limit: 2)

    assert_equal 'Prusa XL', series.first.first
    assert_in_delta 2.0, series.first.last.find { |label, _| label == 'All time' }.last
  end
end
