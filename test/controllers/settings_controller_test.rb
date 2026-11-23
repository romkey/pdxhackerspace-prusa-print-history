require 'test_helper'

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test 'anonymous users are redirected to login' do
    get settings_path

    assert_redirected_to login_path
  end

  test 'non-admin users get 403' do
    login_as(users(:viewer))
    get settings_path

    assert_response :forbidden
  end

  test 'admins can view settings' do
    login_as(users(:admin))
    get settings_path

    assert_response :success
    assert_select 'h1', text: /Settings/
    assert_select 'textarea[name="settings[prusa_untrained_message]"]'
    assert_select 'textarea[name="settings[prusa_trained_account_message]"]'
  end

  test 'admins can update settings' do
    login_as(users(:admin))
    patch settings_path, params: {
      settings: {
        default_ambient_sensor: 'sensor.new_ambient',
        dashboard_heading: 'PDX Hackerspace 3D Printers',
        footer_text: 'PDX Hackerspace 3D Printing',
        footer_link_label: 'FAQ',
        footer_link_url: 'https://example.com/faq',
        prusa_untrained_message: 'Do not print without training.',
        prusa_trained_account_message: 'Ask for Prusa on your account.'
      }
    }

    assert_redirected_to settings_path
    assert_equal 'sensor.new_ambient', Setting.default_ambient_sensor
    assert_equal 'PDX Hackerspace 3D Printers', Setting.dashboard_heading
    assert_equal 'PDX Hackerspace 3D Printing', Setting.footer_text
    assert_equal 'FAQ', Setting.footer_link_label
    assert_equal 'https://example.com/faq', Setting.footer_link_url
    assert_equal 'Do not print without training.', Setting.prusa_untrained_message
    assert_equal 'Ask for Prusa on your account.', Setting.prusa_trained_account_message
  end

  test 'admins can update the API settings without touching the others' do
    Setting.dashboard_heading = 'Keep me'
    login_as(users(:admin))

    patch settings_path, params: {
      settings: {
        api_enabled: '1', api_members_can_create_tokens: '0', members_can_undo_clear: '0',
        api_member_max_access_level: 'read', api_member_token_default_days: '30',
        api_member_token_max_days: '', api_token_max_login_age_days: '14', api_kiosk_session_minutes: '5',
        login_link_ttl_minutes: '30', login_links_allow_admins: '1'
      }
    }

    assert_redirected_to settings_path
    assert Setting.api_enabled?
    assert_not Setting.api_members_can_create_tokens?
    assert_not Setting.members_can_undo_clear?
    assert_equal 'read', Setting.api_member_max_access_level
    assert_equal 30, Setting.api_member_token_default_days
    assert_nil Setting.api_member_token_max_days
    assert_equal 14, Setting.api_token_max_login_age_days
    assert_equal 5, Setting.api_kiosk_session_minutes
    assert_equal 30, Setting.login_link_ttl_minutes
    assert Setting.login_links_allow_admins?
    assert_equal 'Keep me', Setting.dashboard_heading
  end

  test 'settings page shows the API section' do
    login_as(users(:admin))

    get settings_path

    assert_select '#api input[name=?]', 'settings[api_enabled]'
  end

  test 'non-admins cannot update settings' do
    login_as(users(:viewer))
    patch settings_path, params: { settings: { default_ambient_sensor: 'sensor.nope' } }

    assert_response :forbidden
  end
end
