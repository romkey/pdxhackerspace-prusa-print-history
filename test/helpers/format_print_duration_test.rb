require 'test_helper'

class FormatPrintDurationTest < ActionView::TestCase
  include ApplicationHelper

  test 'format_print_duration renders compact labels' do
    assert_equal '—', format_print_duration(0)
    assert_equal '45m', format_print_duration(2700)
    assert_equal '2h', format_print_duration(7200)
    assert_equal '2h 15m', format_print_duration(8100)
  end
end
