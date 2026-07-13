ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'minitest/mock'

ActiveJob::Base.queue_adapter = :test

# Integration tests use REMOTE_ADDR 127.0.0.1 by default; treat it as an internal
# network so existing anonymous page tests keep working. Use external_request_headers
# when a test needs to simulate a visitor from outside INTERNAL_NETWORKS.
ENV['INTERNAL_NETWORKS'] = '127.0.0.1/32'
InternalNetworks.reset!

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    fixtures :all

    setup do
      encrypt_sensitive_fixtures!
    end

    def encrypt_sensitive_fixtures!
      original = ActiveRecord::Encryption.config.support_unencrypted_data
      ActiveRecord::Encryption.config.support_unencrypted_data = true
      User.find_each { |user| user.encrypt && user.save!(validate: false) }
      Printer.find_each { |printer| printer.encrypt && printer.save!(validate: false) }
    ensure
      ActiveRecord::Encryption.config.support_unencrypted_data = original
    end
  end
end

module ActionDispatch
  class IntegrationTest
    teardown do
      ENV['INTERNAL_NETWORKS'] = '127.0.0.1/32'
      InternalNetworks.reset!
    end

    def login_as(user)
      omniauth_login(user)
    end

    def omniauth_login(user)
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:developer] = omniauth_auth_hash_for(user)
      post '/auth/developer/callback'
      follow_redirect! while response.redirect?
    end

    def omniauth_auth_hash_for(user)
      OmniAuth::AuthHash.new(
        provider: user.provider,
        uid: user.uid,
        info: omniauth_info_for(user),
        extra: omniauth_extra_for(user)
      )
    end

    def omniauth_info_for(user)
      info = { email: user.email, name: user.name, nickname: user.username }
      info[:is_admin] = true if user.provider == 'authentik' && user.admin?
      info
    end

    def omniauth_extra_for(user)
      return {} unless user.provider == 'authentik' && user.slack_id.present?

      {
        raw_info: {
          slack: { uid: user.slack_id, name: user.slack_handle || user.username }
        }
      }
    end

    def internal_request_headers(ip = '192.168.0.50')
      { 'REMOTE_ADDR' => ip }
    end

    def external_request_headers
      { 'REMOTE_ADDR' => '203.0.113.50' }
    end
  end
end
