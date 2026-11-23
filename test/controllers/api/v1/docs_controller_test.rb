require 'test_helper'

module Api
  module V1
    class DocsControllerTest < ActionDispatch::IntegrationTest
      test 'the reference is served as Markdown without a token, even with the API off' do
        get api_v1_docs_path, headers: external_request_headers

        assert_response :success
        assert_equal 'text/markdown', response.media_type
        assert_match(/^# Prusa print history API/, response.body)
      end

      test 'the index points at the reference' do
        get api_v1_path

        assert_response :success
        assert_equal 'v1', json_body['version']
        assert_equal api_v1_docs_url, json_body['docs_url']
      end
    end
  end
end
