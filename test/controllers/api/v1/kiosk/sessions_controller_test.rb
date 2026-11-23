require 'test_helper'

module Api
  module V1
    module Kiosk
      class SessionsControllerTest < ActionDispatch::IntegrationTest
        include ActionMailer::TestHelper

        setup do
          enable_api!
          @admin = users(:admin)
          @member = users(:viewer)
          @member.update!(member_id: 'ak-viewer')
          @device = ApiTokenLifecycle.new(actor: @admin).issue!(owner: @admin, name: 'Door kiosk', kind: 'device',
                                                                access_level: 'read_write_delete',
                                                                expires_in_days: '')
        end

        def start_session(member_id = 'ak-viewer', token: @device)
          post api_v1_kiosk_sessions_path, params: { member_id: }, headers: api_headers(token), as: :json
          json_body['token']
        end

        test 'a device token starts a short session that acts as the member' do
          freeze_time do
            secret = start_session

            assert_response :created
            assert_equal @member.id, json_body.dig('user', 'id')
            assert_equal 2.minutes.from_now.utc.iso8601, json_body['expires_at']

            get api_v1_me_path, headers: api_headers(secret)

            assert_equal @member.id, json_body.dig('user', 'id')
            assert_equal 'kiosk_session', json_body.dig('token', 'kind')
          end
          assert_includes @device.events.reload.map(&:action), 'api.kiosk.session_started'
        end

        test 'a session can claim and clear, and the audit names the kiosk' do
          secret = start_session
          job = jobs(:finished_unclaimed)

          put api_v1_job_claim_path(job), headers: api_headers(secret), as: :json

          assert_response :success
          assert_equal @member, job.reload.owner
          event = ApiTokenEvent.find_by(action: 'api.job.claimed')

          assert_equal @device, event.api_token
          assert_equal @member, event.actor

          JobNotificationService.stub(:notify_print_cleared, JobNotificationService::Result.new(
                                                               email_sent: false, slack_sent: false, errors: []
                                                             )) do
            post api_v1_job_clearance_path(job), params: { outcome: 'success', print_label: false },
                                                 headers: api_headers(secret), as: :json
          end

          assert_response :success
          assert job.reload.cleared?
        end

        test 'a session cannot undo a clear or use endpoints outside the kiosk list' do
          secret = start_session
          job = jobs(:finished)
          job.update!(cleared_at: 1.hour.ago, clear_outcome: 'success')

          delete api_v1_job_clearance_path(job), headers: api_headers(secret)

          assert_response :forbidden
          assert_equal 'not_allowed_for_token_kind', json_body.dig('error', 'code')
        end

        test 'an admin who scans in gets member powers only' do
          @admin.update!(member_id: 'ak-admin')
          secret = start_session('ak-admin')
          job = jobs(:finished_pla)

          put api_v1_job_claim_path(job), headers: api_headers(secret), as: :json

          assert_response :conflict
          assert_equal users(:other_viewer), job.reload.owner
        end

        test 'the device token on its own can read but not act' do
          get api_v1_printers_path, headers: api_headers(@device)

          assert_response :success

          put api_v1_job_claim_path(jobs(:finished_unclaimed)), headers: api_headers(@device), as: :json

          assert_response :forbidden
          assert_equal 'not_allowed_for_token_kind', json_body.dig('error', 'code')
        end

        test 'personal tokens cannot start kiosk sessions' do
          start_session(token: create_api_token(@admin))

          assert_response :forbidden
        end

        test 'unknown member IDs get a helpful 404' do
          start_session('ak-nobody')

          assert_response :not_found
          assert_equal 'member_not_found', json_body.dig('error', 'code')
        end

        test 'pausing the device token ends its sessions' do
          secret = start_session
          @device.update!(paused_at: Time.current)

          get api_v1_me_path, headers: api_headers(secret)

          assert_response :unauthorized
        end

        test 'sessions expire' do
          secret = start_session

          travel 3.minutes do
            get api_v1_me_path, headers: api_headers(secret)

            assert_response :unauthorized
          end
        end

        test 'a kiosk allowed to display links gets a QR link with the short lifetime' do
          secret = start_session

          post api_v1_login_links_path, params: { delivery: 'display' }, headers: api_headers(secret), as: :json

          assert_response :forbidden
          assert_equal 'display_not_allowed', json_body.dig('error', 'code')

          @device.update!(can_display_login_links: true)
          assert_no_enqueued_emails do
            post api_v1_problem_report_links_path, params: { printer_id: printers(:prusa_xl).id, delivery: 'display' },
                                                   headers: api_headers(secret), as: :json
          end

          assert_response :accepted
          assert_match %r{/login/link/}, json_body['url']
          assert_equal 'display', LoginLink.last.delivery
        end

        test 'kiosk sessions are not listed with tokens' do
          start_session
          login_as(@admin)

          get api_tokens_path

          assert_select 'a', text: /Kiosk session/, count: 0
          assert_select 'a', text: 'Door kiosk'
        end
      end
    end
  end
end
