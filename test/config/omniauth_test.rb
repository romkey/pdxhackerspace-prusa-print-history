require 'test_helper'

class OmniauthTest < ActiveSupport::TestCase
  test 'Authentik authorize requests has_slack scope' do
    assert_equal %i[openid email profile has_slack], AUTHENTIK_SCOPES
    assert_not_includes AUTHENTIK_SCOPES, :slack
  end

  test 'Authentik authorize requests is_admin claim only' do
    claims = JSON.parse(AUTHENTIK_CLAIMS.to_json)

    assert_equal %w[is_admin], claims.fetch('userinfo').keys
    assert_not claims.fetch('userinfo').key?('slack')
    assert_not claims.fetch('userinfo').key?('has_slack')
  end
end
