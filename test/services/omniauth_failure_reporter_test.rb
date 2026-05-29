require 'test_helper'

class OmniauthFailureReporterTest < ActiveSupport::TestCase
  test 'uses omniauth error message when failure param is absent' do
    request = auth_failure_request(
      error: StandardError.new('JWT signature invalid'),
      error_type: nil
    )

    result = OmniauthFailureReporter.report(request)

    assert_equal 'Sign-in failed: JWT signature invalid', result.user_message
  end

  test 'maps known omniauth error types to friendly messages' do
    request = auth_failure_request(
      error: StandardError.new('invalid_grant'),
      error_type: 'invalid_credentials'
    )

    result = OmniauthFailureReporter.report(request)

    assert_equal 'Sign-in failed: Authentik rejected the sign-in. invalid_grant', result.user_message
  end

  test 'falls back to query param message' do
    request = auth_failure_request(params: { message: 'csrf_detected', strategy: 'authentik' })

    result = OmniauthFailureReporter.report(request)

    assert_equal 'Sign-in failed: Your sign-in session expired. Please try again.', result.user_message
  end

  test 'logs exception class message and backtrace' do
    io = StringIO.new
    old_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    error = RuntimeError.new('token exchange failed')
    error.set_backtrace(['omniauth/openid_connect.rb:42:in `callback_phase`'])
    request = auth_failure_request(error: error, error_type: 'invalid_response')

    OmniauthFailureReporter.report(request)

    log = io.string

    assert_includes log, '[auth] Sign-in failed (strategy=authentik'
    assert_includes log, '[auth] RuntimeError: token exchange failed'
    assert_includes log, '[auth]   omniauth/openid_connect.rb:42'
  ensure
    Rails.logger = old_logger
  end

  test 'logs when no error details are present' do
    io = StringIO.new
    old_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    request = auth_failure_request

    OmniauthFailureReporter.report(request)

    assert_includes io.string, '[auth] No omniauth.error or message param in request'
  ensure
    Rails.logger = old_logger
  end

  private

  def auth_failure_request(error: nil, error_type: nil, params: {})
    env = Rack::MockRequest.env_for("/auth/failure?#{Rack::Utils.build_query(params)}")
    env['omniauth.error'] = error if error
    env['omniauth.error.type'] = error_type if error_type
    env['omniauth.error.strategy'] = Struct.new(:name).new('authentik') if error || error_type
    ActionDispatch::Request.new(env)
  end
end
