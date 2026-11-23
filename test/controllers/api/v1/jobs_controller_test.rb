require 'test_helper'

module Api
  module V1
    class JobsControllerTest < ActionDispatch::IntegrationTest
      setup do
        enable_api!
        @member = users(:viewer)
        @token = create_api_token(@member)
      end

      test 'lists recent jobs' do
        get api_v1_jobs_path, headers: api_headers(@token)

        assert_response :success
        assert_equal Job.count, json_body['jobs'].size
      end

      test 'filters by state, printer and ownership' do
        get api_v1_jobs_path(state: 'active'), headers: api_headers(@token)

        assert_equal [jobs(:active_xl).id, jobs(:orphaned_active).id].sort, json_body['jobs'].pluck('id').sort

        get api_v1_jobs_path(state: 'uncleared', printer_id: printers(:prusa_mk4).id), headers: api_headers(@token)

        assert(json_body['jobs'].all? { |job| job.dig('printer', 'name') == 'Prusa MK4' })

        get api_v1_jobs_path(mine: true), headers: api_headers(@token)

        assert_equal [jobs(:active_xl).id, jobs(:finished).id].sort, json_body['jobs'].pluck('id').sort
      end

      test 'limit caps the number of jobs' do
        get api_v1_jobs_path(limit: 2), headers: api_headers(@token)

        assert_equal 2, json_body['jobs'].size
      end

      test 'shows a single job' do
        get api_v1_job_path(jobs(:finished)), headers: api_headers(@token)

        assert_equal 'vase.gcode', json_body.dig('job', 'filename')
        assert_equal 'Prusa XL', json_body.dig('job', 'printer', 'name')
      end
    end
  end
end
