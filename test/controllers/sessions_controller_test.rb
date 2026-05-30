require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test 'login page renders' do
    get login_path

    assert_response :success
    assert_select 'h1', text: /Sign in/
  end

  test 'login page highlights Authentik above local accounts when both are configured' do
    ENV['AUTHENTIK_ISSUER'] = 'https://authentik.example.com/application/o/app/'
    ENV['LOCAL_ADMIN_EMAIL'] = 'admin@localhost'
    ENV['LOCAL_ADMIN_PASSWORD'] = 'local-secret'

    get login_path

    assert_response :success
    assert_select 'form[action=?][method=?]', '/auth/authentik', 'post' do
      assert_select 'button.btn-primary', text: /Sign in with Authentik/
    end
    assert_select 'details summary', text: 'Local account sign-in'
    assert_select 'form[action=?]', local_login_path do
      assert_select 'input[type=submit].btn-outline-secondary[value=?]', 'Sign in'
    end
  ensure
    ENV.delete('AUTHENTIK_ISSUER')
    ENV.delete('LOCAL_ADMIN_EMAIL')
    ENV.delete('LOCAL_ADMIN_PASSWORD')
  end

  test 'login page uses primary local sign-in when Authentik is not configured' do
    ENV.delete('AUTHENTIK_ISSUER')
    ENV['LOCAL_ADMIN_EMAIL'] = 'admin@localhost'
    ENV['LOCAL_ADMIN_PASSWORD'] = 'local-secret'

    get login_path

    assert_response :success
    assert_select '.h-section-label', text: 'Local accounts', count: 0
    assert_select 'form[action=?]', local_login_path do
      assert_select 'input[type=submit].btn-primary[value=?]', 'Sign in'
    end
  ensure
    ENV.delete('LOCAL_ADMIN_EMAIL')
    ENV.delete('LOCAL_ADMIN_PASSWORD')
  end

  test 'authentik sign-in demotes a former admin without is_admin claim' do
    admin = users(:admin)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: admin.uid,
      info: { email: admin.email, name: admin.name, nickname: admin.username }
    )

    post '/auth/developer/callback'

    follow_redirect!

    assert_response :success
    assert_not admin.reload.admin?
  end

  test 'authentik sign-in promotes user when is_admin claim is true' do
    user = users(:viewer)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: user.uid,
      info: { email: user.email, name: user.name, nickname: user.username, is_admin: true }
    )

    post '/auth/developer/callback'

    follow_redirect!

    assert_response :success
    assert_predicate user.reload, :admin?
  end

  test 'sign-in records last login time' do
    user = users(:viewer)
    user.update!(last_login_at: 1.week.ago)

    travel_to Time.zone.parse('2026-05-30 12:00:00') do
      login_as(user)

      assert_in_delta Time.current, user.reload.last_login_at, 1.second
    end
  end

  test 'developer omniauth flow creates a user and logs them in' do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
      provider: 'developer',
      uid: 'fresh-user@example.com',
      info: { email: 'fresh-user@example.com', name: 'Fresh User', nickname: 'freshuser' }
    )

    assert_difference -> { User.count } => 1 do
      post '/auth/developer/callback'
    end

    follow_redirect!

    assert_response :success
    assert_match(/Signed in as freshuser/, flash[:notice].to_s)
    assert_nil flash[:warning]
  end

  test 'authentik callback warns when member lacks Prusa training' do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'untrained-uid',
      info: { email: 'untrained@example.com', name: 'Untrained User', nickname: 'untrained' },
      extra: { raw_info: { trained_on: ['Laser'] } }
    )

    post '/auth/developer/callback'

    follow_redirect!

    assert_response :success
    assert_match(/Signed in as untrained/, flash[:notice].to_s)
    assert_includes flash[:warning], Setting::DEFAULT_PRUSA_UNTRAINED_MESSAGE
    assert_includes flash[:warning], Setting::DEFAULT_PRUSA_TRAINED_ACCOUNT_MESSAGE
  end

  test 'authentik callback does not warn when member is trained on Prusa' do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'trained-uid',
      info: { email: 'trained@example.com', name: 'Trained User', nickname: 'trained' },
      extra: { raw_info: { trained_on: %w[Prusa Laser] } }
    )

    post '/auth/developer/callback'

    follow_redirect!

    assert_response :success
    assert_nil flash[:warning]
  end

  test 'callback logs auth hash when AUTHENTIK_DEBUG is enabled' do
    ENV['AUTHENTIK_DEBUG'] = 'true'
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
      provider: 'developer',
      uid: 'debug-user@example.com',
      info: { email: 'debug-user@example.com', name: 'Debug User' },
      extra: { raw_info: { is_admin: false } },
      credentials: { token: 'secret-token' }
    )

    logs = capture_authentik_logs do
      post '/auth/developer/callback'
    end

    assert_match(/\[Authentik JSON\] ← omniauth.auth/, logs)
    assert_match(/"email": "debug-user@example.com"/, logs)
    assert_includes logs, AuthentikDebug::REDACTED
    assert_no_match(/secret-token/, logs)
  ensure
    ENV.delete('AUTHENTIK_DEBUG')
  end

  test 'callback does not log auth hash when AUTHENTIK_DEBUG is disabled' do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
      provider: 'developer',
      uid: 'quiet-user@example.com',
      info: { email: 'quiet-user@example.com', name: 'Quiet User' }
    )

    logs = capture_authentik_logs do
      post '/auth/developer/callback'
    end

    assert_no_match(/\[Authentik JSON\]/, logs)
  end

  test 'logout clears the session' do
    login_as(users(:admin))

    delete logout_path

    assert_redirected_to root_path

    get settings_path

    assert_redirected_to login_path
  end

  test 'local login creates an admin session when configured' do
    ENV['LOCAL_ADMIN_EMAIL'] = 'local-admin@example.com'
    ENV['LOCAL_ADMIN_PASSWORD'] = 'local-secret'

    assert_difference -> { User.count } => 1 do
      post local_login_path, params: { email: 'local-admin@example.com', password: 'local-secret' }
    end

    follow_redirect!

    assert_response :success
    assert_match(/Signed in as local-admin/, flash[:notice].to_s)

    get settings_path

    assert_response :success
  ensure
    ENV.delete('LOCAL_ADMIN_EMAIL')
    ENV.delete('LOCAL_ADMIN_PASSWORD')
  end

  test 'local login rejects bad credentials' do
    ENV['LOCAL_ADMIN_EMAIL'] = 'local-admin@example.com'
    ENV['LOCAL_ADMIN_PASSWORD'] = 'local-secret'

    assert_no_difference -> { User.count } do
      post local_login_path, params: { email: 'local-admin@example.com', password: 'wrong' }
    end

    assert_redirected_to login_path
    assert_match(/Invalid email or password/, flash[:alert].to_s)
  ensure
    ENV.delete('LOCAL_ADMIN_EMAIL')
    ENV.delete('LOCAL_ADMIN_PASSWORD')
  end

  test 'local login is unavailable when not configured' do
    post local_login_path, params: { email: 'any@example.com', password: 'secret' }

    assert_response :not_found
  end

  test 'auth failure endpoint uses query param message' do
    get '/auth/failure', params: { message: 'csrf_detected', strategy: 'authentik' }

    assert_redirected_to login_path
    assert_match(/session expired/i, flash[:alert].to_s)
  end

  test 'auth failure redirects logged-in users without showing an error' do
    login_as(users(:viewer))

    get '/auth/failure', params: { message: 'csrf_detected', strategy: 'authentik' }

    assert_redirected_to root_path
    assert_match(/Signed in as vieweruser/, flash[:notice].to_s)
    assert_nil flash[:alert]
  end

  test 'successful callback clears a stale failure flash' do
    get '/auth/failure', params: { message: 'csrf_detected', strategy: 'authentik' }

    assert_redirected_to login_path
    assert_match(/session expired/i, flash[:alert].to_s)

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
      provider: 'developer',
      uid: 'fresh-user@example.com',
      info: { email: 'fresh-user@example.com', name: 'Fresh User', nickname: 'freshuser' }
    )

    post '/auth/developer/callback'
    follow_redirect!

    assert_response :success
    assert_match(/Signed in as freshuser/, flash[:notice].to_s)
    assert_nil flash[:alert]
  end

  test 'callback reports validation errors when user cannot be saved' do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
      provider: 'developer',
      uid: '',
      info: { email: '', name: '' }
    )

    assert_no_difference -> { User.count } do
      post '/auth/developer/callback'
    end

    assert_redirected_to login_path
    assert_match(/Sign-in failed:/, flash[:alert].to_s)
  end

  private

  def capture_authentik_logs
    io = StringIO.new
    old_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = old_logger
  end
end
