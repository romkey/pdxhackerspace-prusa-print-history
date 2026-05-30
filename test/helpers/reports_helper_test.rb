require 'test_helper'

class ReportsHelperTest < ActionView::TestCase
  include ReportsHelper

  test 'attention_events_report_summary counts printers and total events' do
    rows = [
      AttentionEventsReport::Row.new(key: '1', label: 'Prusa XL', week_count: 1, month_count: 1, all_count: 2),
      AttentionEventsReport::Row.new(key: '2', label: 'Prusa MK4', week_count: 0, month_count: 0, all_count: 0)
    ]

    summary = attention_events_report_summary(rows).to_s

    assert_match(/with attention events/, summary)
    assert_match(%r{>2</span> total}, summary)
    assert_match(/text-body fw-medium/, summary)
  end

  test 'format_report_count_cell mutes zero counts' do
    assert_match(/text-secondary/, format_report_count_cell(0))
    assert_equal 3, format_report_count_cell(3)
  end
end
