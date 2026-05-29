module AuthentikDebug
  class FaradayMiddleware < Faraday::Middleware
    def call(env)
      AuthentikDebug.log_http_request(env)
      @app.call(env).on_complete do |response_env|
        AuthentikDebug.log_http_response(response_env)
      end
    end
  end
end
