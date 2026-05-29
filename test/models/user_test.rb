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

  test 'display_name falls back to email' do
    assert_equal @admin.name, @admin.display_name

    nameless = User.create!(email: 'nameless@example.com', provider: 'authentik', uid: 'nameless-uid')

    assert_equal 'nameless@example.com', nameless.display_name
  end

  test 'find_or_create_from_auth promotes admin emails from ADMIN_EMAILS' do
    ENV['ADMIN_EMAILS'] = 'promoted@example.com'
    AdminEmails.reset!

    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'promo-uid',
      info: { email: 'promoted@example.com', name: 'Promoted Person' }
    )

    user = User.find_or_create_from_auth(auth)

    assert_predicate user, :persisted?
    assert_predicate user, :admin?
    assert_equal 'promoted@example.com', user.email
  ensure
    ENV.delete('ADMIN_EMAILS')
    AdminEmails.reset!
  end

  test 'find_or_create_from_auth updates existing user without demoting admin' do
    auth = OmniAuth::AuthHash.new(
      provider: @admin.provider,
      uid: @admin.uid,
      info: { email: @admin.email, name: 'Renamed Admin' }
    )

    user = User.find_or_create_from_auth(auth)

    assert_equal @admin.id, user.id
    assert_equal 'Renamed Admin', user.name
    assert_predicate user, :admin?
  end

  test 'find_or_create_from_auth stores slack fields from OIDC raw_info' do
    auth = OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'slack-uid',
      info: { email: 'slack@example.com', name: 'Slack User' },
      extra: { raw_info: { 'slack_user_id' => 'UOIDC123', 'slack_handle' => '@makerbot' } }
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
      extra: { raw_info: { slack_user_id: 'UNEW', slack_handle: 'newhandle' } }
    )

    User.find_or_create_from_auth(auth)

    user.reload

    assert_equal 'UNEW', user.slack_id
    assert_equal 'newhandle', user.slack_handle
  end

  test 'find_or_create_from_auth leaves slack fields unchanged when claims are absent' do
    user = users(:viewer)

    auth = OmniAuth::AuthHash.new(
      provider: user.provider,
      uid: user.uid,
      info: { email: user.email, name: user.name }
    )

    User.find_or_create_from_auth(auth)

    assert_equal 'UVIEWER123', user.reload.slack_id
  end

  test 'normalizes slack_handle by stripping @ prefix' do
    user = users(:viewer)
    user.slack_handle = '@makerbot'
    user.save!

    assert_equal 'makerbot', user.slack_handle
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
end
