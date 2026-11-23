require 'test_helper'

class LoginLinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = users(:viewer)
    @link = LoginLink.create!(user: @member, return_to: '/service/problems/new?printer_id=1',
                              expires_at: 10.minutes.from_now)
  end

  test 'opening a link only asks for confirmation and does not use it up' do
    get login_link_path(@link.secret), headers: external_request_headers

    assert_response :success
    assert_select 'h1', text: /Sign in as #{@member.display_name}/
    assert_equal 'no-store', response.headers['Cache-Control']
    assert @link.reload.usable?
  end

  test 'confirming signs in and goes to the requested page' do
    post login_link_path(@link.secret), headers: external_request_headers

    assert_redirected_to '/service/problems/new?printer_id=1'
    assert_not @link.reload.usable?
    follow_redirect!(headers: external_request_headers)

    assert_response :success
  end

  test 'a used, expired or unknown link does not sign in' do
    @link.consume

    post login_link_path(@link.secret)

    assert_response :gone
    assert_select 'h1', text: /no longer works/

    get login_link_path('not-a-real-token')

    assert_response :gone
  end

  test 'an admin link stops working if admin links are not allowed' do
    admin_link = LoginLink.create!(user: users(:admin), expires_at: 10.minutes.from_now)

    post login_link_path(admin_link.secret)

    assert_response :gone

    Setting.login_links_allow_admins = true
    post login_link_path(admin_link.secret)

    assert_redirected_to '/'
  end

  test 'links stop working when sign-in links are turned off' do
    Setting.login_links_enabled = false

    post login_link_path(@link.secret)

    assert_response :gone
  end
end
