require 'test_helper'

module Api
  module V1
    class LoginLinksControllerTest < ActionDispatch::IntegrationTest
      include ActionMailer::TestHelper

      setup do
        enable_api!
        @member = users(:viewer)
        @token = create_api_token(@member, access_level: 'read_write')
        @previous_smtp = ENV.fetch('SMTP_SERVER', nil)
        ENV['SMTP_SERVER'] = 'smtp.example.com'
      end

      teardown do
        ENV['SMTP_SERVER'] = @previous_smtp
      end

      test 'emails the token owner a sign-in link and says where it went' do
        assert_enqueued_emails 1 do
          post api_v1_login_links_path, params: { return_to: '/jobs' }, headers: api_headers(@token), as: :json
        end

        assert_response :accepted
        assert_equal 'email', json_body['delivery']
        assert_equal 'v***@example.com', json_body['sent_to']
        assert_nil json_body['url']
        assert_equal '/jobs', LoginLink.last.return_to
        assert_equal @token, LoginLink.last.requested_by_token
        assert_equal 'api.login_link.requested', ApiTokenEvent.last.action
      end

      test 'a problem report link lands on the form for that printer' do
        printer = printers(:prusa_mk4)

        post api_v1_problem_report_links_path, params: { printer_id: printer.id }, headers: api_headers(@token),
                                               as: :json

        assert_response :accepted
        assert_equal "/service/problems/new?printer_id=#{printer.id}", LoginLink.last.return_to
      end

      test 'off-site return paths are replaced with the home page' do
        post api_v1_login_links_path, params: { return_to: 'https://evil.example' }, headers: api_headers(@token),
                                      as: :json

        assert_equal '/', LoginLink.last.return_to
      end

      test 'admins get a clear refusal unless admin links are allowed' do
        admin_token = create_api_token(users(:admin))

        post api_v1_login_links_path, headers: api_headers(admin_token), as: :json

        assert_response :forbidden
        assert_equal 'admin_login_links_disabled', json_body.dig('error', 'code')
      end

      test 'personal tokens cannot ask for a link to display' do
        post api_v1_login_links_path, params: { delivery: 'display' }, headers: api_headers(@token), as: :json

        assert_response :forbidden
        assert_equal 'display_not_allowed', json_body.dig('error', 'code')
      end

      test 'read-only tokens cannot request links' do
        post api_v1_login_links_path, headers: api_headers(create_api_token(@member, access_level: 'read')), as: :json

        assert_response :forbidden
      end
    end
  end
end
