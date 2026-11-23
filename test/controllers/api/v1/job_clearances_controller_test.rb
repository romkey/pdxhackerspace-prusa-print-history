require 'test_helper'

module Api
  module V1
    class JobClearancesControllerTest < ActionDispatch::IntegrationTest
      NO_NOTIFICATION = JobNotificationService::Result.new(email_sent: false, slack_sent: true, errors: [])

      setup do
        enable_api!
        @member = users(:other_viewer)
        @token = create_api_token(@member)
        @job = jobs(:finished)
      end

      def clear(params, token: @token)
        JobNotificationService.stub(:notify_print_cleared, NO_NOTIFICATION) do
          post api_v1_job_clearance_path(@job), params:, headers: api_headers(token), as: :json
        end
      end

      test 'clears a failed print with a reason, from outside the shop network' do
        JobNotificationService.stub(:notify_print_cleared, NO_NOTIFICATION) do
          post api_v1_job_clearance_path(@job), params: { outcome: 'failed', failure_reason: 'spaghetti' },
                                                headers: api_headers(@token, ip: '203.0.113.50'), as: :json
        end

        assert_response :success
        assert_equal 'failed', @job.reload.clear_outcome
        assert_equal 'spaghetti', @job.clear_failure_reason
        assert_equal @member, @job.cleared_by
        assert_equal 'failed', json_body.dig('job', 'clearance', 'outcome')
        assert json_body.dig('notification', 'slack_sent')
        assert_not json_body.dig('label', 'printed')
        assert_equal 'api.job.cleared', ApiTokenEvent.last.action
      end

      test 'a successful clear prints a pickup label by default' do
        JobLabelPrintService.stub(:call, 42) do
          clear({ outcome: 'success' })
        end

        assert_response :success
        assert_equal 42, json_body.dig('label', 'cups_job_id')
      end

      test 'print_label false skips the label' do
        JobLabelPrintService.stub(:call, ->(**) { flunk 'label printed' }) do
          clear({ outcome: 'success', print_label: false })
        end

        assert_response :success
        assert @job.reload.cleared?
      end

      test 'without a label printer a success clears quietly unless a label was asked for' do
        LabelPrinter.delete_all

        clear({ outcome: 'success', print_label: true })

        assert_response :unprocessable_content
        assert_not @job.reload.cleared?

        clear({ outcome: 'success' })

        assert_response :success
        assert @job.reload.cleared?
      end

      test 'invalid outcomes and missing reasons are 422' do
        clear({ outcome: 'maybe' })

        assert_response :unprocessable_content
        assert_equal 'unprocessable', json_body.dig('error', 'code')

        clear({ outcome: 'failed', failure_reason: 'other' })

        assert_response :unprocessable_content
        assert_match(/Details are required/, json_body.dig('error', 'message'))
      end

      test 'clearing twice is a conflict' do
        @job.update!(cleared_at: 1.hour.ago, clear_outcome: 'success')

        clear({ outcome: 'success', print_label: false })

        assert_response :conflict
      end

      test 'undoing a clear follows the members_can_undo_clear setting' do
        @job.update!(cleared_at: 1.hour.ago, clear_outcome: 'success', cleared_by: users(:admin))
        Setting.members_can_undo_clear = false

        delete api_v1_job_clearance_path(@job), headers: api_headers(@token)

        assert_response :forbidden
        assert @job.reload.cleared?

        Setting.members_can_undo_clear = true
        delete api_v1_job_clearance_path(@job), headers: api_headers(@token)

        assert_response :success
        assert_not @job.reload.cleared?
        assert json_body.dig('job', 'actions', 'can_clear')
      end

      test 'clear options list outcomes, reasons and label printers' do
        get api_v1_clear_options_path, headers: api_headers(@token)

        assert_equal %w[success failed], json_body['outcomes']
        assert_includes json_body['failure_reasons'], { 'value' => 'spaghetti', 'label' => 'Spaghetti' }
        assert_equal ['other'], json_body['detail_required_for']
        assert json_body['label_printers'].first['default']
      end
    end
  end
end
