require 'test_helper'

class ReportsControllerTest < ActionDispatch::IntegrationTest
  test 'anonymous users are redirected to login' do
    get reports_path

    assert_redirected_to login_path
  end

  test 'non-admin users get 403' do
    login_as(users(:viewer))
    get reports_path

    assert_response :forbidden
  end

  test 'admins can view reports index' do
    login_as(users(:admin))

    get reports_path

    assert_response :success
    assert_select 'h1', text: 'Reports'
    assert_select 'a.nav-link.active', text: 'Reports'
  end

  test 'admins can view print time sub-reports' do
    login_as(users(:admin))

    get printers_reports_path

    assert_response :success
    assert_select 'h1', text: 'Print time by printer'
    assert_select 'th', text: 'Last 7 days'

    get users_reports_path

    assert_response :success
    assert_select 'h1', text: 'Print time by user'

    get filament_reports_path

    assert_response :success
    assert_select 'h1', text: 'Print time by filament'
    assert_match(/PLA/, response.body)
  end

  test 'navbar shows reports link only for admins' do
    login_as(users(:admin))
    get root_path

    assert_select 'a.nav-link', text: 'Reports'

    login_as(users(:viewer))
    get root_path

    assert_select 'a.nav-link', text: 'Reports', count: 0
  end
end
