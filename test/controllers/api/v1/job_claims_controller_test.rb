require 'test_helper'

module Api
  module V1
    class JobClaimsControllerTest < ActionDispatch::IntegrationTest
      setup do
        enable_api!
        @member = users(:viewer)
        @token = create_api_token(@member)
        @job = jobs(:finished_unclaimed)
      end

      test 'claims an unclaimed print, optionally as private, and audits it' do
        put api_v1_job_claim_path(@job), params: { private: true }, headers: api_headers(@token), as: :json

        assert_response :success
        assert_equal @member, @job.reload.owner
        assert @job.private?
        assert json_body.dig('job', 'actions', 'can_release_claim')
        assert_equal 'api.job.claimed', ApiTokenEvent.last.action
        assert_equal @token, ApiTokenEvent.last.api_token
      end

      test 'refuses to take over someone else\'s claim' do
        @job.update!(owner: users(:other_viewer))

        put api_v1_job_claim_path(@job), headers: api_headers(@token), as: :json

        assert_response :conflict
        assert_equal 'conflict', json_body.dig('error', 'code')
        assert_equal users(:other_viewer), @job.reload.owner
      end

      test 'admins can take over a claim' do
        @job.update!(owner: users(:other_viewer))

        put api_v1_job_claim_path(@job), headers: api_headers(create_api_token(users(:admin))), as: :json

        assert_response :success
        assert_equal users(:admin), @job.reload.owner
      end

      test 'releasing needs the delete level and ownership' do
        @job.update!(owner: @member, private: true)

        delete api_v1_job_claim_path(@job), headers: api_headers(create_api_token(@member, access_level: 'read_write'))

        assert_response :forbidden
        assert_equal 'insufficient_access_level', json_body.dig('error', 'code')

        delete api_v1_job_claim_path(@job), headers: api_headers(@token)

        assert_response :success
        assert_nil @job.reload.owner
        assert_not @job.private?
      end

      test 'members cannot release someone else\'s claim' do
        @job.update!(owner: users(:other_viewer))

        delete api_v1_job_claim_path(@job), headers: api_headers(@token)

        assert_response :forbidden
        assert_equal users(:other_viewer), @job.reload.owner
      end

      test 'read-only tokens cannot claim' do
        put api_v1_job_claim_path(@job), headers: api_headers(create_api_token(@member, access_level: 'read')),
                                         as: :json

        assert_response :forbidden
        assert_nil @job.reload.owner
      end
    end
  end
end
