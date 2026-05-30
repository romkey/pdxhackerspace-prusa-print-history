require 'test_helper'

class PrinterStatusPartialTest < ActionView::TestCase
  test 'idle reachable printer uses a green dot' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true, operational_state: 'idle')

    render partial: 'shared/printer_status', locals: { printer: printer }

    assert_select '.status-dot.status-success', count: 1
    assert_select '.status-dot.status-danger', count: 0
    assert_match(/idle/, rendered)
  end

  test 'idle unreachable printer uses a red dot' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: false, operational_state: 'idle')

    render partial: 'shared/printer_status', locals: { printer: printer }

    assert_select '.status-dot.status-danger', count: 1
    assert_select '.status-dot.status-success', count: 0
  end

  test 'idle unconfigured printer uses a red dot' do
    printer = printers(:prusa_mk4)
    printer.update!(prusalink_key: nil, operational_state: 'idle')

    render partial: 'shared/printer_status', locals: { printer: printer }

    assert_select '.status-dot.status-danger', count: 1
  end

  test 'printing printer keeps a green dot with status label' do
    printer = printers(:prusa_xl)

    render partial: 'shared/printer_status', locals: { printer: printer }

    assert_select '.status-dot.status-success', count: 1
    assert_match(/printing/, rendered)
  end
end
