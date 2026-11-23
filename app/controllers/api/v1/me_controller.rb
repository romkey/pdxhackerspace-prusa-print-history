module Api
  module V1
    # Token introspection: who the token acts as and what it may do.
    class MeController < BaseController
      allow_device_tokens :show
      allow_kiosk_sessions :show

      def show
        render json: {
          user: Api::V1::Json.user(current_user, include_admin: true),
          token: Api::V1::Json.token(current_token, effective_access_level: current_access_level)
        }
      end
    end
  end
end
