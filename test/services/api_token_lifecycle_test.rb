require 'test_helper'

class ApiTokenLifecycleTest < ActiveSupport::TestCase
  setup do
    @member = users(:viewer)
    @admin = users(:admin)
  end

  def lifecycle(actor = @member)
    ApiTokenLifecycle.new(actor:, ip: '10.0.0.9')
  end

  test 'issue! creates a token with the requested expiry and records who created it' do
    freeze_time do
      token = lifecycle.issue!(owner: @member, name: 'Script', access_level: 'read', expires_in_days: '10')

      assert_equal 10.days.from_now, token.expires_at
      assert_equal @member, token.created_by
      assert token.secret.present?
      assert_equal %w[created], token.events.map(&:action)
      assert_equal '10.0.0.9', token.events.first.ip
    end
  end

  test 'issue! refuses no expiry or too long an expiry when a maximum is set' do
    Setting.api_member_token_max_days = '30'

    error = assert_raises(ApiTokenLifecycle::Error) do
      lifecycle.issue!(owner: @member, name: 'Script', access_level: 'read', expires_in_days: '')
    end
    assert_match(/within 30 days/, error.message)

    assert_raises(ApiTokenLifecycle::Error) do
      lifecycle.issue!(owner: @member, name: 'Script', access_level: 'read', expires_in_days: '31')
    end
  end

  test 'issue! allows a token that never expires when no maximum is set' do
    token = lifecycle.issue!(owner: @member, name: 'Kiosk', access_level: 'read', expires_in_days: '')

    assert_nil token.expires_at
  end

  test 'issue! refuses access levels above the member cap' do
    Setting.api_member_max_access_level = 'read'

    assert_raises(ApiTokenLifecycle::Error) do
      lifecycle.issue!(owner: @member, name: 'Script', access_level: 'read_write', expires_in_days: '5')
    end
  end

  test 'members cannot issue tokens for others, admins can' do
    assert_raises(ApiTokenLifecycle::Error) do
      lifecycle.issue!(owner: @admin, name: 'x', access_level: 'read', expires_in_days: '5')
    end

    token = lifecycle(@admin).issue!(owner: @member, name: 'For Ada', access_level: 'read', expires_in_days: '5')

    assert_equal @member, token.user
    assert_equal @admin, token.created_by
  end

  test 'pause, resume, rotate and revoke change state and are audited' do
    token = create_api_token(@member)
    old_digest = token.token_digest

    lifecycle.pause!(token)

    assert token.paused?

    lifecycle.resume!(token)

    assert_not token.paused?

    lifecycle.rotate!(token)

    assert_not_equal old_digest, token.token_digest

    lifecycle.revoke!(token)

    assert token.revoked?
    assert_equal %w[revoked rotated resumed paused], token.events.reload.map(&:action)
    assert_raises(ApiTokenLifecycle::Error) { lifecycle.resume!(token) }
  end

  test 'renew! extends from now by the lifetime the token was issued with' do
    token = lifecycle.issue!(owner: @member, name: 'Script', access_level: 'read', expires_in_days: '10')
    token.update!(expires_at: 2.days.ago)

    freeze_time do
      lifecycle.renew!(token)

      assert_equal 10.days.from_now, token.expires_at
    end
  end

  test 'renew! keeps a time-limited token time-limited when the default is never expire' do
    Setting.api_member_token_default_days = ''
    token = create_api_token(@member, expires_at: 1.day.from_now)

    freeze_time do
      lifecycle.renew!(token)

      assert_equal 365.days.from_now, token.expires_at
    end
  end

  test 'renew! is capped by the current maximum' do
    token = lifecycle.issue!(owner: @member, name: 'Script', access_level: 'read', expires_in_days: '100')
    Setting.api_member_token_max_days = '30'

    freeze_time do
      lifecycle.renew!(token)

      assert_equal 30.days.from_now, token.expires_at
    end
  end

  test 'renew! refuses a revoked token and a token that never expires' do
    assert_raises(ApiTokenLifecycle::Error) { lifecycle.renew!(create_api_token(@member)) }
    assert_raises(ApiTokenLifecycle::Error) do
      lifecycle.renew!(create_api_token(@member, expires_at: 1.day.from_now, revoked_at: Time.current))
    end
  end

  test 'other members cannot manage a token' do
    token = create_api_token(@member)

    assert_raises(ApiTokenLifecycle::Error) { lifecycle(users(:other_viewer)).pause!(token) }
    lifecycle(@admin).pause!(token)

    assert token.paused?
  end
end
