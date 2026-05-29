ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'minitest/mock'

ActiveJob::Base.queue_adapter = :test

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    fixtures :all
  end
end

module ActionDispatch
  class IntegrationTest
    def login_as(user)
      omniauth_login(user)
    end

    def omniauth_login(user)
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
        provider: user.provider,
        uid: user.uid,
        info: { email: user.email, name: user.name, nickname: user.username }
      )
      post '/auth/developer/callback'
      follow_redirect! while response.redirect?
    end
  end
end
