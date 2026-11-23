require 'test_helper'

module Api
  module V1
    class ProblemsControllerTest < ActionDispatch::IntegrationTest
      setup do
        enable_api!
        @member = users(:viewer)
        @token = create_api_token(@member, access_level: 'read_write')
        @printer = printers(:prusa_mk4)
      end

      test 'files a problem report as the token owner' do
        assert_difference -> { @printer.service_entries.count }, 1 do
          post api_v1_printer_problems_path(@printer),
               params: { summary: 'Nozzle clogged', details: 'Under-extruding' },
               headers: api_headers(@token), as: :json
        end

        assert_response :created
        assert_equal 'problem', json_body.dig('problem', 'kind')
        assert_equal @member.id, json_body.dig('problem', 'reported_by', 'id')
        assert_not json_body['printer_out_of_service']
        assert_equal 'api.printer.problem_reported', ApiTokenEvent.last.action
      end

      test 'can take the printer out of service at the same time' do
        post api_v1_printer_problems_path(@printer), params: { summary: 'Bed cracked', take_out_of_service: true },
                                                     headers: api_headers(@token), as: :json

        assert_response :created
        assert json_body['printer_out_of_service']
        assert @printer.reload.out_of_service?
      end

      test 'a summary is required' do
        post api_v1_printer_problems_path(@printer), params: { summary: ' ' }, headers: api_headers(@token), as: :json

        assert_response :unprocessable_content
        assert_match(/Summary/, json_body.dig('error', 'message'))
      end

      test 'read-only tokens cannot report problems' do
        read_only = create_api_token(@member, access_level: 'read')
        post api_v1_printer_problems_path(@printer), params: { summary: 'x' }, headers: api_headers(read_only),
                                                     as: :json

        assert_response :forbidden
      end
    end
  end
end
