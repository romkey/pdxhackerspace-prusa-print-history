require 'test_helper'

module Api
  module V1
    class PrintersControllerTest < ActionDispatch::IntegrationTest
      setup do
        enable_api!
        @token = create_api_token(users(:other_viewer), access_level: 'read')
      end

      test 'lists every printer with the print to act on and what the caller may do' do
        get api_v1_printers_path, headers: api_headers(@token)

        assert_response :success
        xl = json_body['printers'].find { |printer| printer['name'] == 'Prusa XL' }

        assert_equal jobs(:active_xl).id, xl.dig('job', 'id')
        assert_equal 'printing', xl.dig('job', 'status')
        assert xl.dig('job', 'claimed')
        assert_not xl.dig('job', 'actions', 'can_claim'), 'someone else owns it'
        assert xl.dig('job', 'actions', 'can_clear')
        assert_includes json_body['printers'].pluck('name'), 'Bambu P2S'
      end

      test 'active=true keeps only printers with a print in progress or waiting to be cleared' do
        jobs(:finished_old).update!(cleared_at: 1.day.ago, clear_outcome: 'success')

        get api_v1_printers_path(active: true), headers: api_headers(@token)

        names = json_body['printers'].pluck('name')

        assert_equal ['Prusa MK4', 'Prusa XL'], names
      end

      test 'a finished print still on the bed is offered for clearing' do
        get api_v1_printer_path(printers(:prusa_mini)), headers: api_headers(@token)

        assert_equal jobs(:finished_old).id, json_body.dig('printer', 'job', 'id')
        assert json_body.dig('printer', 'job', 'actions', 'can_clear')
      end

      test 'private prints hide their details from other members' do
        jobs(:active_xl).update!(private: true)

        get api_v1_printer_path(printers(:prusa_xl)), headers: api_headers(@token)

        assert_nil json_body.dig('printer', 'job', 'filename')
        assert_nil json_body.dig('printer', 'job', 'owner')
      end

      test 'unknown printers are a 404 in the error envelope' do
        get api_v1_printer_path(id: 0), headers: api_headers(@token)

        assert_response :not_found
        assert_equal 'not_found', json_body.dig('error', 'code')
      end
    end
  end
end
