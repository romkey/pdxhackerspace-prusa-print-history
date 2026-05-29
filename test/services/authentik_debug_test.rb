require 'test_helper'

class AuthentikDebugTest < ActiveSupport::TestCase
  setup do
    @original_debug = ENV.fetch('AUTHENTIK_DEBUG', nil)
    ENV.delete('AUTHENTIK_DEBUG')
  end

  teardown do
    if @original_debug.nil?
      ENV.delete('AUTHENTIK_DEBUG')
    else
      ENV['AUTHENTIK_DEBUG'] = @original_debug
    end
  end

  test 'enabled? is false by default' do
    assert_not AuthentikDebug.enabled?
  end

  test 'enabled? reads AUTHENTIK_DEBUG environment variable' do
    ENV['AUTHENTIK_DEBUG'] = 'true'

    assert_predicate AuthentikDebug, :enabled?

    ENV['AUTHENTIK_DEBUG'] = '0'

    assert_not AuthentikDebug.enabled?
  end

  test 'log_outbound writes pretty JSON when debug is enabled' do
    ENV['AUTHENTIK_DEBUG'] = 'true'
    logs = capture_authentik_logs do
      AuthentikDebug.log_outbound('POST', 'https://authentik.example.com/token', { grant_type: 'authorization_code' })
    end

    assert_match(%r{\[Authentik JSON\] → POST https://authentik.example.com/token}, logs)
    assert_match(/"grant_type": "authorization_code"/, logs)
  end

  test 'log_inbound writes pretty JSON when debug is enabled' do
    ENV['AUTHENTIK_DEBUG'] = 'true'
    logs = capture_authentik_logs do
      AuthentikDebug.log_inbound('200 GET userinfo', { email: 'user@example.com', is_admin: false })
    end

    assert_match(/\[Authentik JSON\] ← 200 GET userinfo/, logs)
    assert_match(/"is_admin": false/, logs)
  end

  test 'does not log when debug is disabled' do
    logs = capture_authentik_logs do
      AuthentikDebug.log_outbound('GET', 'https://authentik.example.com/authorize', { client_id: 'abc' })
      AuthentikDebug.log_inbound('omniauth.auth', { uid: '123' })
      AuthentikDebug.log_auth_hash(build_auth_hash)
    end

    assert_empty logs
  end

  test 'redacts sensitive token and secret fields' do
    ENV['AUTHENTIK_DEBUG'] = 'true'
    logs = capture_authentik_logs do
      AuthentikDebug.log_inbound(
        'token',
        {
          access_token: 'secret-token',
          refresh_token: 'secret-refresh',
          id_token: 'secret-id',
          client_secret: 'secret-client',
          code: 'auth-code',
          email: 'user@example.com'
        }
      )
    end

    assert_includes logs, AuthentikDebug::REDACTED
    assert_no_match(/secret-token/, logs)
    assert_no_match(/secret-refresh/, logs)
    assert_no_match(/secret-id/, logs)
    assert_no_match(/secret-client/, logs)
    assert_no_match(/auth-code/, logs)
    assert_match(/"email": "user@example.com"/, logs)
  end

  test 'log_authorize_uri parses claims JSON from redirect query' do
    ENV['AUTHENTIK_DEBUG'] = 'true'
    claims = { userinfo: { is_admin: nil } }.to_json
    uri = "https://authentik.example.com/application/o/authorize/?client_id=abc&scope=openid+email+profile+has_slack&claims=#{CGI.escape(claims)}"

    logs = capture_authentik_logs do
      AuthentikDebug.log_authorize_uri(uri)
    end

    assert_match(%r{\[Authentik JSON\] → GET https://authentik.example.com/application/o/authorize/}, logs)
    assert_match(/"is_admin": null/, logs)
    assert_no_match(/"slack":/, logs)
    assert_match(/"scope": "openid email profile has_slack"/, logs)
  end

  test 'log_auth_hash includes provider info and redacted credentials' do
    ENV['AUTHENTIK_DEBUG'] = 'true'
    auth = build_auth_hash

    logs = capture_authentik_logs do
      AuthentikDebug.log_auth_hash(auth)
    end

    assert_match(/\[Authentik JSON\] ← omniauth.auth/, logs)
    assert_match(/"provider": "authentik"/, logs)
    assert_match(/"email": "user@example.com"/, logs)
    assert_match(/"is_admin": true/, logs)
    assert_match(/"uid": "U123"/, logs)
    assert_includes logs, AuthentikDebug::REDACTED
    assert_no_match(/raw-access-token/, logs)
  end

  private

  def build_auth_hash
    OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'auth-subject',
      info: { email: 'user@example.com', name: 'User' },
      extra: { raw_info: { is_admin: true, slack: { uid: 'U123', name: 'makerbot' } } },
      credentials: { token: 'raw-access-token', id_token: 'raw-id-token' }
    )
  end

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
