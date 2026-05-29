require 'test_helper'

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test 'profile requires login' do
    get profile_path

    assert_redirected_to login_path
  end

  test 'user can update notification preferences' do
    login_as(users(:viewer))
    ENV['SMTP_ADDRESS'] = 'smtp.example.com'

    patch profile_path, params: { user: { notify_via_email: '1', notify_via_slack: '0', slack_id: 'UVIEWER123' } }

    assert_redirected_to profile_path
    assert users(:viewer).reload.notify_via_email?
  ensure
    ENV.delete('SMTP_ADDRESS')
  end

  test 'profile hides email option when SMTP is not configured' do
    ENV.delete('SMTP_ADDRESS')
    ENV.delete('MAIL_HOST')
    login_as(users(:viewer))

    get profile_path

    assert_no_match(/notify_via_email/, response.body)
    assert_match(/SMTP is not configured/i, response.body)
  end

  test 'profile hides slack option when Slack is not configured' do
    ENV.delete('SLACK_API_TOKEN')
    login_as(users(:viewer))

    get profile_path

    assert_no_match(/notify_via_slack/, response.body)
    assert_match(/Slack is not configured/i, response.body)
  end
end
