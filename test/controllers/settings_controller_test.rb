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
  end

  test 'admins can update settings' do
    login_as(users(:admin))
    patch settings_path, params: {
      settings: {
        default_ambient_sensor: 'sensor.new_ambient',
        dashboard_heading: 'PDX Hackerspace 3D Printers',
        footer_text: 'PDX Hackerspace 3D Printing',
        footer_link_label: 'FAQ',
        footer_link_url: 'https://example.com/faq'
      }
    }

    assert_redirected_to settings_path
    assert_equal 'sensor.new_ambient', Setting.default_ambient_sensor
    assert_equal 'PDX Hackerspace 3D Printers', Setting.dashboard_heading
    assert_equal 'PDX Hackerspace 3D Printing', Setting.footer_text
    assert_equal 'FAQ', Setting.footer_link_label
    assert_equal 'https://example.com/faq', Setting.footer_link_url
  end

  test 'non-admins cannot update settings' do
    login_as(users(:viewer))
    patch settings_path, params: { settings: { default_ambient_sensor: 'sensor.nope' } }

    assert_response :forbidden
  end
end
