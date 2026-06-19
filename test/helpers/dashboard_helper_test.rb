require 'test_helper'

class DashboardHelperTest < ActionView::TestCase
  include DashboardHelper

  setup do
    @presenter = DashboardPresenter.new(
      printers: Printer.ordered.includes(:printer_heads),
      active_jobs_by_printer: {},
      last_jobs_by_printer: {},
      recent_events: [],
      filters: %w[idle PLA],
      current_user: nil
    )
  end

  def dashboard_active_filters
    @presenter.active_filters
  end

  test 'dashboard_filter_href stacks and removes filters' do
    assert_equal root_path(filter: %w[idle PLA PETG]), dashboard_filter_href('PETG')
    assert_equal root_path(filter: ['PLA']), dashboard_filter_href('idle')
    assert_equal root_path(filter: ['idle']), dashboard_filter_href('PLA')
  end

  test 'dashboard_filter_href clears all filters when removing the last one' do
    @presenter = DashboardPresenter.new(
      printers: Printer.ordered.includes(:printer_heads),
      active_jobs_by_printer: {},
      last_jobs_by_printer: {},
      recent_events: [],
      filters: ['idle'],
      current_user: nil
    )

    assert_equal root_path, dashboard_filter_href('idle')
  end

  test 'dashboard_filter_chip_class marks active filters' do
    assert_equal 'filter-chip active', dashboard_filter_chip_class('idle')
    assert_equal 'filter-chip', dashboard_filter_chip_class('offline')
  end

  test 'dashboard_status_filter_label humanizes filter names' do
    assert_equal 'Available', dashboard_status_filter_label('available')
    assert_equal 'My prints', dashboard_status_filter_label('my_prints')
  end
end
