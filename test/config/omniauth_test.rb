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
end
