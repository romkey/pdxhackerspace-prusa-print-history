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
    assert_select 'a[href=?]', attention_reports_path
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
    assert_match(/Unclaimed/, response.body)

    get filament_reports_path

    assert_response :success
    assert_select 'h1', text: 'Print time by filament'
    assert_match(/PLA/, response.body)
  end

  test 'users print time report shows unclaimed row and duration' do
    login_as(users(:admin))

    get users_reports_path

    assert_response :success
    assert_select 'td', text: 'Unclaimed'
    assert_match(/1h 30m|1h/, response.body)
  end

  test 'admins can view attention events report' do
    login_as(users(:admin))

    get attention_reports_path

    assert_response :success
    assert_select 'h1', text: 'Attention events by printer'
    assert_select 'a.nav-link.active', text: 'Attention · Printers'
    assert_select 'td', text: 'Prusa MK4'
    assert_select 'td.num', text: '1'
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
