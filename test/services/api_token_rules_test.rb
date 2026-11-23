require 'test_helper'

class ApiTokenRulesTest < ActiveSupport::TestCase
  setup do
    @member = users(:viewer)
    @admin = users(:admin)
  end

  test 'lifetimes come from the role\'s settings and are capped by the maximum' do
    Setting.api_member_token_default_days = '30'
    Setting.api_admin_token_default_days = '7'

    assert_equal 30, ApiTokenRules.default_days_for(@member)
    assert_equal 7, ApiTokenRules.default_days_for(@admin)

    Setting.api_member_token_max_days = '10'

    assert_equal 10, ApiTokenRules.default_days_for(@member)
  end

  test 'a blank default falls back to the maximum, or to no expiry' do
    Setting.api_member_token_default_days = ''

    assert_nil ApiTokenRules.default_days_for(@member)
    assert ApiTokenRules.never_expires_allowed?(@member)

    Setting.api_member_token_max_days = '60'

    assert_equal 60, ApiTokenRules.default_days_for(@member)
    assert_not ApiTokenRules.never_expires_allowed?(@member)
  end

  test 'member levels are capped by the setting; admins get every level' do
    Setting.api_member_max_access_level = 'read'

    assert_equal %w[read], ApiTokenRules.levels_for(@member)
    assert_equal ApiToken::ACCESS_LEVELS, ApiTokenRules.levels_for(@admin)
  end

  test 'the effective level follows the owner\'s current role' do
    Setting.api_member_max_access_level = 'read_write'
    token = create_api_token(@admin, access_level: 'read_write_delete')

    assert_equal 'read_write_delete', ApiTokenRules.effective_level(token)

    @admin.update!(admin: false)

    assert_equal 'read_write', ApiTokenRules.effective_level(token.reload)
  end

  test 'members create their own tokens only when allowed; admins create for anyone' do
    assert ApiTokenRules.can_create_for?(@member, @member)
    assert_not ApiTokenRules.can_create_for?(@member, @admin)
    assert ApiTokenRules.can_create_for?(@admin, @member)

    Setting.api_members_can_create_tokens = false

    assert_not ApiTokenRules.can_create_for?(@member, @member)
    assert ApiTokenRules.can_create_for?(@admin, @member)
  end

  test 'owners and admins manage a token; other members do not' do
    token = create_api_token(@member)

    assert ApiTokenRules.can_manage?(@member, token)
    assert ApiTokenRules.can_manage?(@admin, token)
    assert_not ApiTokenRules.can_manage?(users(:other_viewer), token)
  end

  test 'expired tokens can be renewed only within the grace period' do
    token = create_api_token(@member, expires_at: 10.days.ago)

    assert ApiTokenRules.renewable?(token)

    Setting.api_token_renew_grace_days = '5'

    assert_not ApiTokenRules.renewable?(token)

    Setting.api_token_renew_grace_days = ''

    assert_not ApiTokenRules.renewable?(token)
    assert_not ApiTokenRules.renewable?(create_api_token(@member, revoked_at: Time.current))
  end

  test 'sign-in age is enforced only when set' do
    @member.update!(last_login_at: 40.days.ago)

    assert_not ApiTokenRules.login_too_old?(@member)

    Setting.api_token_max_login_age_days = '30'

    assert ApiTokenRules.login_too_old?(@member)

    @member.update!(last_login_at: 1.day.ago)

    assert_not ApiTokenRules.login_too_old?(@member)
  end
end
