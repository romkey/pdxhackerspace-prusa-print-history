require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  test 'anonymous users are redirected to login' do
    get users_path

    assert_redirected_to login_path
  end

  test 'non-admin users get 403' do
    login_as(users(:viewer))
    get users_path

    assert_response :forbidden
  end

  test 'internal anonymous users cannot access users index' do
    get users_path, headers: internal_request_headers

    assert_redirected_to login_path
  end

  test 'admins can view users index' do
    login_as(users(:admin))
    get users_path

    assert_response :success
    assert_select 'h1', text: 'Users'
    assert_select 'a.nav-link.active', text: 'Users'
  end

  test 'users index lists users alphabetically' do
    login_as(users(:admin))
    get users_path

    body = response.body
    admin_index = body.index('adminuser')
    other_index = body.index('otherviewer')
    viewer_index = body.index('vieweruser')

    assert admin_index
    assert other_index
    assert viewer_index
    assert_operator admin_index, :<, other_index
    assert_operator other_index, :<, viewer_index
  end

  test 'users index shows admin and prusa training from last login' do
    users(:admin).update!(last_login_at: 1.day.ago)
    users(:viewer).update!(last_login_at: 2.days.ago, trained_on_prusa: true)

    login_as(users(:admin))
    get users_path

    assert_select 'th', text: 'Admin'
    assert_select 'th', text: 'Prusa'
    assert_select 'span.badge', text: 'Yes'
    assert_select 'span.fw-medium', text: 'Yes'
  end

  test 'users index shows profile fields claimed jobs and last login' do
    viewer = users(:viewer)
    viewer.update!(last_login_at: 2.days.ago)

    login_as(users(:admin))
    get users_path

    body = response.body

    assert_match jobs(:active_xl).filename, body
    assert_match jobs(:finished).filename, body
    assert_match(/2 days ago/, body)
    assert_match viewer.email, body
    assert_match(/@#{viewer.slack_handle}/, body)
    assert_match viewer.slack_id, body
  end

  test 'navbar shows users link only for admins' do
    login_as(users(:admin))
    get root_path

    assert_select 'a.nav-link', text: 'Users'

    login_as(users(:viewer))
    get root_path

    assert_select 'a.nav-link', text: 'Users', count: 0
  end

  private

  def internal_request_headers
    { 'REMOTE_ADDR' => '192.168.0.50' }
  end
end
