require 'test_helper'

class PrusalinkStatusDotPartialTest < ActionView::TestCase
  test 'renders green dot when PrusaLink is reachable' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true)

    render partial: 'printers/prusalink_status_dot', locals: { printer: printer }

    assert_select '.status-dot.status-success[title=?]', 'PrusaLink connected'
  end

  test 'renders red dot when PrusaLink is unreachable' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: false)

    render partial: 'printers/prusalink_status_dot', locals: { printer: printer }

    assert_select '.status-dot.status-danger[title=?]', 'PrusaLink unreachable'
  end
end
