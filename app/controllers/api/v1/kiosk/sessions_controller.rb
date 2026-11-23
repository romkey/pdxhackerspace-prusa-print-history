module Api
  module V1
    module Kiosk
      # A kiosk's device token exchanges a member's Authentik member ID for a short-lived
      # token that acts as that member.
      class SessionsController < BaseController
        ATTEMPTS_PER_MINUTE = 30

        allow_device_tokens :create

        rate_limit to: ATTEMPTS_PER_MINUTE, within: 1.minute, by: -> { current_token.id },
                   with: -> { render_error(:too_many_requests, 'rate_limited', 'Too many scans. Wait a minute.') }

        def create
          return forbidden!('Only a kiosk device token can start kiosk sessions.') unless current_token.device?

          session = KioskSessionIssuer.call(device_token: current_token, member_id: params[:member_id],
                                            ip: request.remote_ip)
          render json: session_json(session), status: :created
        rescue KioskSessionIssuer::Error => e
          render_error(e.status, e.code, e.message)
        rescue ActiveRecord::RecordInvalid => e
          render_error(:unprocessable_content, 'unprocessable', e.record.errors.full_messages.to_sentence)
        end

        private

        def session_json(session)
          {
            token: session.secret,
            expires_at: Json.time(session.expires_at),
            access_level: ApiTokenRules.effective_level(session),
            can_display_login_links: current_token.can_display_login_links?,
            user: Json.user(session.user)
          }
        end
      end
    end
  end
end
