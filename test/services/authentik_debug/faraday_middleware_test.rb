require 'test_helper'

module AuthentikDebug
  class FaradayMiddlewareTest < ActiveSupport::TestCase
    setup do
      @original_debug = ENV.fetch('AUTHENTIK_DEBUG', nil)
      ENV.delete('AUTHENTIK_DEBUG')
    end

    teardown do
      if @original_debug.nil?
        ENV.delete('AUTHENTIK_DEBUG')
      else
        ENV['AUTHENTIK_DEBUG'] = @original_debug
      end
    end

    test 'logs HTTP request and response when debug is enabled' do
      ENV['AUTHENTIK_DEBUG'] = 'true'
      connection = build_connection(status: 200, body: { email: 'user@example.com' })

      logs = capture_authentik_logs do
        connection.get('/application/o/userinfo/')
      end

      assert_match(%r{\[Authentik JSON\] → GET https://authentik.example.com/application/o/userinfo/}, logs)
      assert_match(%r{\[Authentik JSON\] ← 200 GET https://authentik.example.com/application/o/userinfo/}, logs)
      assert_match(/"email": "user@example.com"/, logs)
    end

    test 'does not log HTTP traffic when debug is disabled' do
      connection = build_connection(status: 200, body: { email: 'user@example.com' })

      logs = capture_authentik_logs do
        connection.get('/application/o/userinfo/')
      end

      assert_empty logs
    end

    test 'redacts token fields in HTTP JSON payloads' do
      ENV['AUTHENTIK_DEBUG'] = 'true'
      connection = build_connection(
        status: 200,
        body: { access_token: 'secret-token', token_type: 'Bearer', expires_in: 3600 }
      )

      logs = capture_authentik_logs do
        connection.post('/application/o/token/') do |request|
          request.body = { grant_type: 'authorization_code', code: 'auth-code', client_secret: 'secret' }
        end
      end

      assert_includes logs, AuthentikDebug::REDACTED
      assert_no_match(/secret-token/, logs)
      assert_no_match(/auth-code/, logs)
      assert_match(/"token_type": "Bearer"/, logs)
    end

    private

    def build_connection(status:, body:)
      Faraday.new(url: 'https://authentik.example.com') do |faraday|
        faraday.request :json
        faraday.response :json
        faraday.use AuthentikDebug::FaradayMiddleware
        faraday.adapter :test do |stub|
          stub.get('/application/o/userinfo/') do
            [status, { 'Content-Type' => 'application/json' }, body.to_json]
          end
          stub.post('/application/o/token/') do
            [status, { 'Content-Type' => 'application/json' }, body.to_json]
          end
        end
      end
    end

    def capture_authentik_logs
      io = StringIO.new
      old_logger = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(io)
      yield
      io.string
    ensure
      Rails.logger = old_logger
    end
  end
end
