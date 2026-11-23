require 'test_helper'

class LoginLinkIssuerTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @member = users(:viewer)
    @previous_smtp = ENV.fetch('SMTP_SERVER', nil)
    ENV['SMTP_SERVER'] = 'smtp.example.com'
  end

  teardown do
    ENV['SMTP_SERVER'] = @previous_smtp
  end

  def issue(**)
    LoginLinkIssuer.call(user: @member, **)
  end

  test 'emails a single-use link that expires after the configured time' do
    Setting.login_link_ttl_minutes = '20'

    freeze_time do
      result = nil
      assert_enqueued_emails 1 do
        result = issue(return_to: '/jobs?owner=me')
      end

      assert_equal 20.minutes.from_now, result.link.expires_at
      assert_equal '/jobs?owner=me', result.link.return_to
      assert_match %r{/login/link/#{Regexp.escape(result.link.secret)}\z}, result.url
    end
  end

  test 'emailed links default to one hour' do
    freeze_time do
      assert_equal 60.minutes.from_now, issue.link.expires_at
    end
  end

  test 'a blank lifetime setting falls back to that setting\'s own default' do
    Setting.login_link_ttl_minutes = ''
    Setting.login_link_qr_ttl_minutes = ''

    freeze_time do
      assert_equal 60.minutes.from_now, issue.link.expires_at
      assert_equal 5.minutes.from_now, issue(delivery: 'display', display_allowed: true).link.expires_at
    end
  end

  test 'refuses when links are off, for admins unless allowed, and when email is not set up' do
    Setting.login_links_enabled = false

    assert_equal 'login_links_disabled', assert_raises(LoginLinkIssuer::Error) { issue }.code

    Setting.login_links_enabled = true

    error = assert_raises(LoginLinkIssuer::Error) { LoginLinkIssuer.call(user: users(:admin)) }

    assert_equal 'admin_login_links_disabled', error.code

    Setting.login_links_allow_admins = true

    assert LoginLinkIssuer.call(user: users(:admin)).link.persisted?

    ENV['SMTP_SERVER'] = nil
    error = assert_raises(LoginLinkIssuer::Error) { issue }

    assert_equal 'email_unavailable', error.code
    assert_equal :service_unavailable, error.status
  end

  test 'display delivery needs permission and uses the shorter lifetime' do
    error = assert_raises(LoginLinkIssuer::Error) { issue(delivery: 'display') }

    assert_equal 'display_not_allowed', error.code

    freeze_time do
      result = nil
      assert_no_enqueued_emails do
        result = issue(delivery: 'display', display_allowed: true)
      end

      assert_equal 5.minutes.from_now, result.link.expires_at
      assert_equal 'display', result.link.delivery
    end
  end

  test 'limits how many links one member can request' do
    3.times { issue }

    error = assert_raises(LoginLinkIssuer::Error) { issue }

    assert_equal 'rate_limited', error.code
    assert_equal :too_many_requests, error.status
  end

  test 'unknown delivery methods are a bad request' do
    assert_equal 'bad_request', assert_raises(LoginLinkIssuer::Error) { issue(delivery: 'carrier_pigeon') }.code
  end
end
