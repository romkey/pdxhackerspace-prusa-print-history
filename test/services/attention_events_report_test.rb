require 'test_helper'

class AttentionEventsReportTest < ActiveSupport::TestCase
  test 'by_printer includes all printers with attention event counts' do
    rows = AttentionEventsReport.by_printer.index_by(&:label)

    assert_equal 1, rows['Prusa XL'].week_count
    assert_equal 1, rows['Prusa XL'].month_count
    assert_equal 1, rows['Prusa XL'].all_count
    assert_equal 1, rows['Prusa MK4'].week_count
    assert_equal 1, rows['Prusa MK4'].all_count
    assert_equal 0, rows['Prusa Mini'].week_count
    assert_equal 0, rows['Prusa Mini'].month_count
    assert_equal 1, rows['Prusa Mini'].all_count
  end

  test 'by_printer lists every printer even when attention count is zero' do
    rows = AttentionEventsReport.by_printer

    assert_equal Printer.count, rows.size
    assert(rows.all? { |row| row.key.present? && row.label.present? })
  end

  test 'chart_series excludes printers with no attention events' do
    rows = AttentionEventsReport.by_printer
    rows << AttentionEventsReport::Row.new(
      key: 'unused',
      label: 'Unused Printer',
      week_count: 0,
      month_count: 0,
      all_count: 0
    )
    series = AttentionEventsReport.chart_series(rows, limit: 10)
    labels = series.flat_map { |entry| entry[:data].map(&:first) }

    assert_not_includes labels, 'Unused Printer'
    assert_includes labels, 'Prusa MK4'
  end

  test 'chart_series uses multi-series format with event counts' do
    rows = AttentionEventsReport.by_printer
    series = AttentionEventsReport.chart_series(rows, limit: 3)

    assert_equal 'Last 7 days', series.first[:name]
    mk4 = series.first[:data].find { |label, _| label == 'Prusa MK4' }

    assert_equal 1, mk4.last
    assert(series.all? { |entry| entry.key?(:name) && entry.key?(:data) })
  end
end
