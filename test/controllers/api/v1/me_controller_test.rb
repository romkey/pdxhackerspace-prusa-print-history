require 'test_helper'

module Api
  module V1
    class MeControllerTest < ActionDispatch::IntegrationTest
      setup do
        enable_api!
        @token = create_api_token(users(:viewer), access_level: 'read_write_delete')
      end

      test 'returns the owner and the token\'s effective access' do
        Setting.api_member_max_access_level = 'read_write'

        get api_v1_me_path, headers: api_headers(@token)

        assert_response :success
        assert_equal users(:viewer).id, json_body.dig('user', 'id')
        assert_not json_body.dig('user', 'admin')
        assert_equal 'read_write_delete', json_body.dig('token', 'access_level')
        assert_equal 'read_write', json_body.dig('token', 'effective_access_level')
        assert_equal @token.token_prefix, json_body.dig('token', 'prefix')
      end

      test 'refuses a missing or bad token with the generic 401 envelope' do
        get api_v1_me_path

        assert_response :unauthorized
        assert_equal 'unauthorized', json_body.dig('error', 'code')
        assert_match(/Bearer/, response.headers['WWW-Authenticate'])

        get api_v1_me_path, headers: api_headers('pph_wrong')

        assert_response :unauthorized
      end

      test 'refuses a paused token exactly like an unknown one' do
        @token.update!(paused_at: Time.current)
        get api_v1_me_path, headers: api_headers(@token)
        paused_body = response.body

        get api_v1_me_path, headers: api_headers('pph_wrong')

        assert_equal paused_body, response.body
      end

      test 'session cookies do not authenticate API requests' do
        login_as(users(:admin))

        get api_v1_me_path

        assert_response :unauthorized
      end
    end
  end
end
