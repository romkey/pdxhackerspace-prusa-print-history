require 'test_helper'

class MailConfigTest < ActiveSupport::TestCase
  setup do
    @env = ENV.to_h
  end

  teardown do
    ENV.replace(@env)
  end

  test 'configured? is false without SMTP_ADDRESS or MAIL_HOST' do
    ENV.delete('SMTP_ADDRESS')
    ENV.delete('MAIL_HOST')

    assert_not MailConfig.configured?
  end

  test 'configured? is true when SMTP_ADDRESS is set' do
    ENV['SMTP_ADDRESS'] = 'smtp.example.com'

    assert MailConfig.configured?
  end

  test 'smtp_settings includes credentials when provided' do
    ENV['SMTP_ADDRESS'] = 'smtp.example.com'
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

  test 'configured? is true when MAIL_HOST is set' do
    ENV.delete('SMTP_ADDRESS')
    ENV['MAIL_HOST'] = 'smtp.example.com'

    assert MailConfig.configured?
  end

  test 'starttls_enabled? respects SMTP_ENABLE_STARTTLS_AUTO' do
    ENV['SMTP_ENABLE_STARTTLS_AUTO'] = 'false'

    assert_not MailConfig.starttls_enabled?
  end

  test 'apply! configures smtp delivery when configured' do
    ENV['SMTP_ADDRESS'] = 'smtp.example.com'
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
