module Api
  module V1
    # Bearer-token JSON API. No session, no cookies, no CSRF: every request carries
    # `Authorization: Bearer pph_...`. Errors always use one envelope:
    #   { "error": { "code": "not_found", "message": "Not found." } }
    class BaseController < ActionController::API
      REQUESTS_PER_MINUTE = 120
      UNAUTHORIZED_MESSAGE = 'Missing, invalid, expired or paused API token.'.freeze

      rate_limit to: REQUESTS_PER_MINUTE, within: 1.minute, by: -> { request.remote_ip },
                 with: -> { render_error(:too_many_requests, 'rate_limited', 'Too many requests. Retry in a minute.') }

      before_action :authenticate_api_token!
      before_action :require_access_level!

      rescue_from ActiveRecord::RecordNotFound do
        render_error(:not_found, 'not_found', 'Not found.')
      end

      rescue_from ActionController::ParameterMissing do |error|
        render_error(:bad_request, 'bad_request', error.message)
      end

      private

      attr_reader :current_token, :current_user, :current_access_level

      def authenticate_api_token!
        result = ApiTokenAuthenticator.call(secret: bearer_secret, ip: request.remote_ip)
        if result.success?
          @current_token = result.token
          @current_user = result.user
          @current_access_level = result.access_level
          return
        end

        Rails.logger.info("[api] refused #{request.method} #{request.path} " \
                          "from #{request.remote_ip}: #{result.failure}")
        response.headers['WWW-Authenticate'] = 'Bearer realm="api"'
        render_error(:unauthorized, 'unauthorized', UNAUTHORIZED_MESSAGE)
      end

      def require_access_level!
        needed = ApiTokenAuthenticator.level_for_method(request.method)
        return if ApiToken.level_rank(current_access_level) >= ApiToken.level_rank(needed)

        render_error(:forbidden, 'insufficient_access_level',
                     "This token is #{ApiToken::ACCESS_LEVEL_LABELS[current_access_level].downcase}; " \
                     "#{request.method} needs #{ApiToken::ACCESS_LEVEL_LABELS[needed].downcase}.")
      end

      def bearer_secret
        request.authorization.to_s[/\ABearer\s+(\S+)\z/i, 1]
      end

      def access_policy
        @access_policy ||= AccessPolicy.new(user: current_user,
                                            internal_network: InternalNetworks.include?(request.remote_ip))
      end

      def audit!(action, subject: nil, detail: {})
        ApiTokenEvent.record!(action: "api.#{action}", token: current_token, actor: current_user, subject:,
                              ip: request.remote_ip, detail:)
      end

      def render_error(status, code, message, details: nil)
        error = { code:, message: }
        error[:details] = details if details.present?
        render json: { error: }, status:
      end

      def forbidden!(message)
        render_error(:forbidden, 'forbidden', message)
      end
    end
  end
end
