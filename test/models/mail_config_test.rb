require 'test_helper'

class MailConfigTest < ActiveSupport::TestCase
  setup do
    @env = ENV.to_h
  end

  teardown do
    ENV.replace(@env)
  end

  test 'configured? is false without SMTP_SERVER' do
    ENV.delete('SMTP_SERVER')

    assert_not MailConfig.configured?
  end

  test 'configured? is true when SMTP_SERVER is set' do
    ENV['SMTP_SERVER'] = 'smtp.example.com'

    assert MailConfig.configured?
  end

  test 'smtp_settings includes credentials when provided' do
    ENV['SMTP_SERVER'] = 'smtp.example.com'
    ENV['SMTP_USERNAME'] = 'user'
    ENV['SMTP_PASSWORD'] = 'secret'
    ENV['SMTP_PORT'] = '465'
    ENV['SMTP_DOMAIN'] = 'example.com'

    settings = MailConfig.smtp_settings

    assert_equal 'smtp.example.com', settings[:address]
    assert_equal 465, settings[:port]
    assert_equal 'user', settings[:user_name]
    assert_equal 'secret', settings[:password]
    assert_equal 'example.com', settings[:domain]
  end

  test 'starttls_enabled? respects SMTP_ENABLE_STARTTLS_AUTO' do
    ENV['SMTP_ENABLE_STARTTLS_AUTO'] = 'false'

    assert_not MailConfig.starttls_enabled?
  end

  test 'ssl_enabled? respects SMTP_SSL' do
    ENV['SMTP_SSL'] = 'false'

    assert_not MailConfig.ssl_enabled?
  end

  test 'starttls_enabled? is false when SMTP_SSL is false' do
    ENV['SMTP_SSL'] = 'false'
    ENV['SMTP_ENABLE_STARTTLS_AUTO'] = 'true'

    assert_not MailConfig.starttls_enabled?
  end

  test 'smtp_settings disables ssl for plain text mail servers' do
    ENV['SMTP_SERVER'] = 'mailpit'
    ENV['SMTP_PORT'] = '1025'
    ENV['SMTP_SSL'] = 'false'

    settings = MailConfig.smtp_settings

    assert_not settings[:ssl]
    assert_not settings[:enable_starttls_auto]
    assert_equal 1025, settings[:port]
  end

  test 'apply! configures smtp delivery when configured' do
    ENV['SMTP_SERVER'] = 'smtp.example.com'
    mailer = ActiveSupport::OrderedOptions.new
    config = ActiveSupport::OrderedOptions.new
    config.action_mailer = mailer

    MailConfig.apply!(config)

    assert_equal :smtp, mailer.delivery_method
    assert_equal 'smtp.example.com', mailer.smtp_settings[:address]
    assert_equal MailConfig.from_address, mailer.default_options[:from]
  end

  test 'from_address defaults to noreply@localhost' do
    ENV.delete('MAIL_FROM')

    assert_equal 'noreply@localhost', MailConfig.from_address
  end
end
