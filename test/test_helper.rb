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
      info = { email: user.email, name: user.name, nickname: user.username }
      info[:is_admin] = true if user.provider == 'authentik' && user.admin?
      OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
        provider: user.provider,
        uid: user.uid,
        info: info
      )
      post '/auth/developer/callback'
      follow_redirect! while response.redirect?
    end

    def internal_request_headers(ip = '192.168.0.50')
      { 'REMOTE_ADDR' => ip }
    end

    def external_request_headers
      { 'REMOTE_ADDR' => '203.0.113.50' }
    end
  end
end
