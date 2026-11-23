require 'test_helper'

class ApiTokenAuthenticatorTest < ActiveSupport::TestCase
  setup do
    enable_api!
    @member = users(:viewer)
    @token = create_api_token(@member, access_level: 'read_write')
  end

  def authenticate(secret = @token.secret, ip: '127.0.0.1')
    ApiTokenAuthenticator.call(secret:, ip:)
  end

  test 'an active token authenticates as its owner and records its use' do
    result = authenticate

    assert result.success?
    assert_equal @member, result.user
    assert_equal 'read_write', result.access_level
    assert_equal '127.0.0.1', @token.reload.last_used_ip
  end

  test 'nothing authenticates while the API is turned off' do
    Setting.api_enabled = false

    assert_equal :api_disabled, authenticate.failure
  end

  test 'unknown, paused, expired and revoked tokens are refused' do
    assert_equal :unknown_token, authenticate('pph_nope').failure

    @token.update!(paused_at: Time.current)

    assert_equal :token_paused, authenticate.failure

    @token.update!(paused_at: nil, expires_at: 1.second.ago)

    assert_equal :token_expired, authenticate.failure

    @token.update!(expires_at: nil, revoked_at: Time.current)

    assert_equal :token_revoked, authenticate.failure
  end

  test 'address limits and the shop-network setting are enforced' do
    @token.update!(allowed_cidrs: ['10.0.0.0/8'])

    assert_equal :address_not_allowed, authenticate(ip: '192.168.1.1').failure
    assert authenticate(ip: '10.1.2.3').success?

    @token.update!(allowed_cidrs: [])
    Setting.api_require_internal_network = true

    assert_equal :external_network, authenticate(ip: '203.0.113.50').failure
    assert authenticate(ip: '127.0.0.1').success?
  end

  test 'tokens stop working when the owner has not signed in recently enough' do
    Setting.api_token_max_login_age_days = '30'
    @member.update!(last_login_at: 31.days.ago)

    assert_equal :login_too_old, authenticate.failure
  end

  test 'the member access cap lowers the effective level' do
    Setting.api_member_max_access_level = 'read'

    assert_equal 'read', authenticate.access_level
  end

  test 'HTTP methods map to access levels' do
    assert_equal 'read', ApiTokenAuthenticator.level_for_method('GET')
    assert_equal 'read_write', ApiTokenAuthenticator.level_for_method('post')
    assert_equal 'read_write_delete', ApiTokenAuthenticator.level_for_method('DELETE')
  end
end
