require 'test_helper'

module OmniAuth
  module Strategies
    class AuthentikTest < ActiveSupport::TestCase
      test 'uses authentik as the provider name' do
        assert_equal 'authentik', Authentik.default_options[:name]
      end

      test 'inherits from OpenIDConnect strategy' do
        assert_operator Authentik, :<, OmniAuth::Strategies::OpenIDConnect
      end
    end
  end
end
