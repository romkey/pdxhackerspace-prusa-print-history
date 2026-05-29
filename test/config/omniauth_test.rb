require 'test_helper'

class OmniauthTest < ActiveSupport::TestCase
  test 'Authentik authorize requests is_admin, has_slack, and slack claims' do
    claims = JSON.parse(AUTHENTIK_CLAIMS.to_json)

    assert_equal %w[has_slack is_admin slack], claims.fetch('userinfo').keys.sort
  end
end
