require 'test_helper'

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test 'profile requires login' do
    get profile_path

    assert_redirected_to login_path
  end

  test 'user can update notification preferences' do
    login_as(users(:viewer))
    ENV['SMTP_ADDRESS'] = 'smtp.example.com'
    ENV['SLACK_API_TOKEN'] = 'xoxb-test'

    patch profile_path, params: { user: { notify_via_email: '1', notify_via_slack: '1' } }

    assert_redirected_to profile_path
    user = users(:viewer).reload

    assert user.notify_via_email?
    assert user.notify_via_slack?
    assert_equal 'UVIEWER123', user.slack_id
  ensure
    ENV.delete('SMTP_ADDRESS')
    ENV.delete('SLACK_API_TOKEN')
  end

  test 'profile does not expose slack id field' do
    login_as(users(:viewer))

    get profile_path

    assert_no_match(/Slack user ID/i, response.body)
    assert_no_match(/name="user\[slack_id\]"/, response.body)
  end

  test 'profile shows slack handle when slack id is linked' do
    login_as(users(:viewer))

    get profile_path

    assert_match(/@vieweruser/, response.body)
  end

  test 'profile hides slack option when user has no slack id' do
    ENV['SLACK_API_TOKEN'] = 'xoxb-test'
    login_as(users(:other_viewer))

    get profile_path

    assert_no_match(/notify_via_slack/, response.body)
    assert_no_match(/Slack direct message/, response.body)
  ensure
    ENV.delete('SLACK_API_TOKEN')
  end

  test 'profile hides slack option when Slack is not configured' do
    ENV.delete('SLACK_API_TOKEN')
    login_as(users(:viewer))

    get profile_path

    assert_no_match(/notify_via_slack/, response.body)
    assert_match(/Slack is not configured/i, response.body)
    assert_match(/@vieweruser/, response.body)
  end

  test 'profile hides email option when SMTP is not configured' do
    ENV.delete('SMTP_ADDRESS')
    ENV.delete('MAIL_HOST')
    login_as(users(:viewer))

    get profile_path

    assert_no_match(/notify_via_email/, response.body)
    assert_match(/SMTP is not configured/i, response.body)
  end

  test 'profile update cannot change slack id' do
    login_as(users(:viewer))
    ENV['SMTP_ADDRESS'] = 'smtp.example.com'

    patch profile_path, params: { user: { notify_via_email: '0', notify_via_slack: '0', slack_id: 'UHACKED' } }

    assert_redirected_to profile_path
    assert_equal 'UVIEWER123', users(:viewer).reload.slack_id
  ensure
    ENV.delete('SMTP_ADDRESS')
  end
end
