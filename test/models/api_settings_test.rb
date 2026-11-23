require 'test_helper'

class ApiSettingsTest < ActiveSupport::TestCase
  test 'defaults apply until a value is saved' do
    assert_not Setting.api_enabled?
    assert Setting.api_members_can_create_tokens?
    assert Setting.members_can_undo_clear?
    assert_equal 365, Setting.api_member_token_default_days
    assert_nil Setting.api_member_token_max_days
    assert_equal 90, Setting.api_admin_token_default_days
    assert_equal 30, Setting.api_token_renew_grace_days
    assert_equal 'read_write_delete', Setting.api_member_max_access_level
  end

  test 'booleans round-trip' do
    Setting.api_enabled = '1'

    assert Setting.api_enabled?

    Setting.members_can_undo_clear = '0'

    assert_not Setting.members_can_undo_clear?
  end

  test 'a blank day count means none, not the default' do
    Setting.api_member_token_default_days = ''

    assert_nil Setting.api_member_token_default_days

    Setting.api_member_token_default_days = '30'

    assert_equal 30, Setting.api_member_token_default_days
  end

  test 'invalid day counts are stored blank' do
    Setting.api_admin_token_max_days = '-4'

    assert_nil Setting.api_admin_token_max_days

    Setting.api_admin_token_max_days = 'ten'

    assert_nil Setting.api_admin_token_max_days
  end

  test 'unknown member access levels fall back to the default' do
    Setting.api_member_max_access_level = 'read'

    assert_equal 'read', Setting.api_member_max_access_level

    Setting.api_member_max_access_level = 'superuser'

    assert_equal 'read_write_delete', Setting.api_member_max_access_level
  end
end
