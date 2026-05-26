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
end
