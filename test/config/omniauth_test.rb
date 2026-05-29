require 'test_helper'

class OmniauthTest < ActiveSupport::TestCase
  test 'Authentik authorize requests slack scope' do
    assert_equal %i[openid email profile slack], AUTHENTIK_SCOPES
    assert_not_includes AUTHENTIK_SCOPES, :has_slack
    assert_includes AUTHENTIK_SCOPES, :slack
  end

  test 'Authentik authorize requests is_admin claim only' do
    claims = JSON.parse(AUTHENTIK_CLAIMS.to_json)

    assert_equal %w[is_admin], claims.fetch('userinfo').keys
    assert_not claims.fetch('userinfo').key?('slack')
  end

  test 'omniauth rails csrf protection avoids deprecated ActiveSupport::Configurable on Rails 8.1+' do
    spec = Gem.loaded_specs.fetch('omniauth-rails_csrf_protection')

    assert_operator Gem::Version.new(spec.version), :>=, Gem::Version.new('2.0.0')

    next unless ActionPack.version >= Gem::Version.new('8.1.a')

    verifier = OmniAuth::RailsCsrfProtection::TokenVerifier
    uses_deprecated_configurable = verifier.ancestors.any? do |mod|
      mod.name == 'ActiveSupport::Configurable'
    end

    assert_not uses_deprecated_configurable
  end
end
