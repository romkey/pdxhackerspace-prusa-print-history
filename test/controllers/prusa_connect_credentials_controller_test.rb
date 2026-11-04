require 'test_helper'

class PrusaConnectCredentialsControllerTest < ActionDispatch::IntegrationTest
  test 'non-admins are forbidden' do
    login_as(users(:viewer))
    patch prusa_connect_credential_path, params: { refresh_token: 'abc' }

    assert_response :forbidden
    assert_nil PrusaConnectCredential.current
  end

  test 'admins can save and remove the token' do
    login_as(users(:admin))
    patch prusa_connect_credential_path, params: { refresh_token: ' abc ' }

    assert_redirected_to settings_path
    assert_equal 'abc', PrusaConnectCredential.current.refresh_token

    delete prusa_connect_credential_path

    assert_nil PrusaConnectCredential.current
  end
end
