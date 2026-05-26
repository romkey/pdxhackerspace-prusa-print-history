require 'test_helper'

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test 'anonymous visitors can view the dashboard' do
    get root_path

    assert_response :success
    assert_select 'h1', text: /Overview/
  end

  test 'logged-in users can view the dashboard' do
    login_as(users(:viewer))
    get root_path

    assert_response :success
  end

  test 'dashboard shows PrusaLink health dot for configured printers' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: true)

    get root_path

    assert_response :success
    assert_select '.status-dot.status-success[title=?]', 'PrusaLink connected'
  end

  test 'dashboard shows red PrusaLink dot when printer is unreachable' do
    printer = printers(:prusa_xl)
    printer.update!(prusalink_key: 'secret', prusalink_reachable: false)

    get root_path

    assert_response :success
    assert_select '.status-dot.status-danger[title=?]', 'PrusaLink unreachable'
  end
end
