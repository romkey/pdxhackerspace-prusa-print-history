require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test 'login page renders' do
    get login_path

    assert_response :success
    assert_select 'h1', text: /Sign in/
  end

  test 'developer omniauth flow creates a user and logs them in' do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
      provider: 'developer',
      uid: 'fresh-user@example.com',
      info: { email: 'fresh-user@example.com', name: 'Fresh User' }
    )

    assert_difference -> { User.count } => 1 do
      post '/auth/developer/callback'
    end

    follow_redirect!

    assert_response :success
    assert_match(/Signed in as Fresh User/, flash[:notice].to_s)
  end

  test 'logout clears the session' do
    login_as(users(:admin))

    delete logout_path

    assert_redirected_to root_path

    get settings_path

    assert_redirected_to login_path
  end
end
