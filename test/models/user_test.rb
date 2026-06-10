require 'test_helper'

class UserTest < ActiveSupport::TestCase
  setup do
    @admin  = users(:admin)
    @viewer = users(:viewer)
  end

  test 'admin flag works' do
    assert_predicate @admin, :admin?
    assert_not @viewer.admin?
  end

  test 'email is required and unique (case-insensitive)' do
    user = User.new(provider: 'authentik', uid: 'new-uid', name: 'Test')

    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"

    duplicate = User.new(email: 'ADMIN@example.com', provider: 'authentik', uid: 'unique-uid')

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email], 'has already been taken'
  end

  test 'provider + uid is unique' do
    duplicate = User.new(email: 'fresh@example.com', provider: @admin.provider, uid: @admin.uid)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:uid], 'has already been taken'
  end

  test 'email is normalized to lowercase on write' do
    user = User.create!(email: 'NEW@Example.COM', provider: 'authentik', uid: 'norm-uid')

    assert_equal 'new@example.com', user.email
  end

  test 'display_name uses username and falls back to email' do
    assert_equal @admin.username, @admin.display_name

    nameless = User.create!(email: 'nameless@example.com', provider: 'authentik', uid: 'nameless-uid')

    assert_equal 'nameless@example.com', nameless.display_name
  end

  test 'find_or_create_from_auth stores username from nickname' do
    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'nick-uid',
      info: { email: 'nick@example.com', name: 'Nick Name', nickname: 'nickuser' }
    )

    user = User.find_or_create_from_auth(auth)

    assert_equal 'nickuser', user.username
    assert_equal 'Nick Name', user.name
  end

  test 'find_or_create_from_auth updates username on each login' do
    user = User.create!(
      email: 'sync@example.com',
      provider: 'authentik',
      uid: 'sync-nick-uid',
      username: 'oldnick'
    )

    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'sync-nick-uid',
      info: { email: 'sync@example.com', name: 'Sync User', nickname: 'newnick' }
    )

    User.find_or_create_from_auth(auth)

    assert_equal 'newnick', user.reload.username
  end

  test 'find_or_create_from_auth leaves username unchanged when nickname is absent' do
    user = User.create!(
      email: 'nonick@example.com',
      provider: 'authentik',
      uid: 'nonick-uid',
      username: 'keepme'
    )

    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'nonick-uid',
      info: { email: 'nonick@example.com', name: 'No Nick User' }
    )

    User.find_or_create_from_auth(auth)

    assert_equal 'keepme', user.reload.username
  end

  test 'find_or_create_from_auth syncs admin from is_admin claim' do
    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'admin-claim-uid',
      info: { email: 'admin-claim@example.com', name: 'Admin Claim' },
      extra: { raw_info: { is_admin: true } }
    )

    user = User.find_or_create_from_auth(auth)

    assert_predicate user, :admin?

    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'admin-claim-uid',
      info: { email: 'admin-claim@example.com', name: 'Admin Claim' },
      extra: { raw_info: { is_admin: false } }
    )

    User.find_or_create_from_auth(auth)

    assert_not user.reload.admin?
  end

  test 'find_or_create_from_auth demotes admin when is_admin claim is false' do
    auth = OmniAuth::AuthHash.new(
      provider: @admin.provider,
      uid: @admin.uid,
      info: { email: @admin.email, name: 'Renamed Admin' },
      extra: { raw_info: { is_admin: false } }
    )

    user = User.find_or_create_from_auth(auth)

    assert_equal @admin.id, user.id
    assert_equal 'Renamed Admin', user.name
    assert_not user.admin?
  end

  test 'find_or_create_from_auth demotes admin when is_admin claim is absent' do
    auth = OmniAuth::AuthHash.new(
      provider: @admin.provider,
      uid: @admin.uid,
      info: { email: @admin.email, name: 'Renamed Admin' }
    )

    user = User.find_or_create_from_auth(auth)

    assert_equal @admin.id, user.id
    assert_equal 'Renamed Admin', user.name
    assert_not user.admin?
  end

  test 'find_or_create_from_auth reads is_admin from userinfo claims' do
    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'info-admin-uid',
      info: { email: 'info-admin@example.com', name: 'Info Admin', is_admin: true }
    )

    user = User.find_or_create_from_auth(auth)

    assert_predicate user, :admin?
  end

  test 'find_or_create_from_auth syncs trained_on_prusa from trained_on claim' do
    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'trained-uid',
      info: { email: 'trained@example.com', name: 'Trained User' },
      extra: { raw_info: { trained_on: %w[Laser Prusa] } }
    )

    user = User.find_or_create_from_auth(auth)

    assert user.trained_on_prusa?

    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'trained-uid',
      info: { email: 'trained@example.com', name: 'Trained User' },
      extra: { raw_info: { trained_on: ['Laser'] } }
    )

    User.find_or_create_from_auth(auth)

    assert_not user.reload.trained_on_prusa?
  end

  test 'find_or_create_from_auth clears trained_on_prusa when trained_on claim is absent' do
    user = users(:viewer)
    user.update!(trained_on_prusa: true)

    auth = OmniAuth::AuthHash.new(
      provider: user.provider,
      uid: user.uid,
      info: { email: user.email, name: user.name }
    )

    User.find_or_create_from_auth(auth)

    assert_not user.reload.trained_on_prusa?
  end

  test 'find_or_create_from_auth stores slack fields from slack claim' do
    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'slack-uid',
      info: { email: 'slack@example.com', name: 'Slack User' },
      extra: { raw_info: { slack: { uid: 'UOIDC123', name: '@makerbot' } } }
    )

    user = User.find_or_create_from_auth(auth)

    assert_equal 'UOIDC123', user.slack_id
    assert_equal 'makerbot', user.slack_handle
  end

  test 'find_or_create_from_auth updates slack fields on each login' do
    user = User.create!(
      email: 'sync@example.com',
      provider: 'authentik',
      uid: 'sync-uid',
      slack_id: 'UOLD',
      slack_handle: 'oldhandle'
    )

    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'sync-uid',
      info: { email: 'sync@example.com', name: 'Sync User' },
      extra: { raw_info: { slack: { uid: 'UNEW', name: 'newhandle' } } }
    )

    User.find_or_create_from_auth(auth)

    user.reload

    assert_equal 'UNEW', user.slack_id
    assert_equal 'newhandle', user.slack_handle
  end

  test 'find_or_create_from_auth clears slack fields when slack claim is empty' do
    user = User.create!(
      email: 'noslack@example.com',
      provider: 'authentik',
      uid: 'noslack-uid',
      slack_id: 'UOLD',
      slack_handle: 'oldhandle',
      notify_via_slack: true
    )

    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'noslack-uid',
      info: { email: 'noslack@example.com', name: 'No Slack User' },
      extra: { raw_info: { slack: {} } }
    )

    User.find_or_create_from_auth(auth)

    user.reload

    assert_nil user.slack_id
    assert_nil user.slack_handle
    assert_not user.notify_via_slack?
  end

  test 'find_or_create_from_auth clears slack fields when slack claim is absent' do
    user = users(:viewer)

    auth = OmniAuth::AuthHash.new(
      provider: user.provider,
      uid: user.uid,
      info: { email: user.email, name: user.name }
    )

    User.find_or_create_from_auth(auth)

    user.reload

    assert_nil user.slack_id
    assert_nil user.slack_handle
    assert_not user.notify_via_slack?
  end

  test 'trained_on? matches Prusa from array claims' do
    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'trained-uid',
      info: { email: 'trained@example.com', name: 'Trained User' },
      extra: { raw_info: { trained_on: %w[Laser prusa] } }
    )

    assert User.trained_on?(auth, 'Prusa')
    assert_not User.trained_on?(auth, 'Woodshop')
  end

  test 'trained_on_names reads hash entries with name keys' do
    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'hash-trained-uid',
      info: { email: 'hash@example.com', name: 'Hash User' },
      extra: { raw_info: { trained_on: [{ 'name' => 'Prusa' }, { 'title' => 'Laser' }] } }
    )

    assert_equal %w[Prusa Laser], User.trained_on_names(auth)
  end

  test 'trained_on? is false when trained_on claim is absent' do
    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'no-trained-uid',
      info: { email: 'no-trained@example.com', name: 'No Trained User' }
    )

    assert_empty User.trained_on_names(auth)
    assert_not User.trained_on?(auth, 'Prusa')
  end

  test 'normalizes slack_handle by stripping @ prefix' do
    user = users(:viewer)
    user.slack_handle = '@makerbot'
    user.save!

    assert_equal 'makerbot', user.slack_handle
  end

  test 'notification preferences default to enabled' do
    user = User.new(
      email: 'new@example.com',
      name: 'New User',
      provider: 'authentik',
      uid: 'new-uid'
    )

    assert user.notify_via_email?
    assert user.notify_via_slack?
  end

  test 'wants_email_notifications respects user preference and SMTP config' do
    user = users(:viewer)
    ENV['SMTP_SERVER'] = 'smtp.example.com'
    user.update!(notify_via_email: true)

    assert user.wants_email_notifications?

    user.update!(notify_via_email: false)

    assert_not user.wants_email_notifications?
  ensure
    ENV.delete('SMTP_SERVER')
  end

  test 'wants_slack_notifications requires slack id and token' do
    user = users(:viewer)
    ENV['SLACK_API_TOKEN'] = 'xoxb-test'
    user.update!(notify_via_slack: true, slack_id: 'U123')

    assert user.wants_slack_notifications?

    user.update!(notify_via_slack: false, slack_id: nil)

    assert_not user.wants_slack_notifications?
  ensure
    ENV.delete('SLACK_API_TOKEN')
  end

  test 'record_login! stores last_login_at' do
    user = users(:viewer)

    travel_to Time.zone.parse('2026-05-30 12:00:00') do
      user.record_login!

      assert_in_delta Time.current, user.reload.last_login_at, 1.second
    end
  end
end
