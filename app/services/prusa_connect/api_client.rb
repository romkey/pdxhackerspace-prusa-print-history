require 'net/http'
require 'uri'
require 'json'

module PrusaConnect
  # Read-only client for the undocumented Prusa Connect web API (connect.prusa3d.com/app/...).
  # Endpoints, OAuth parameters and field names come from the community-reverse-engineered
  # spec published with https://github.com/dcode/python-prusa-connect-sdk-client — this is an
  # independent implementation, not a port. Prusa can change the API without notice, so callers
  # must treat every failure as non-fatal.
  class ApiClient
    DEFAULT_TIMEOUT = 15
    BASE_URL = ENV.fetch('PRUSA_CONNECT_API_URL', 'https://connect.prusa3d.com')
    TOKEN_URL = ENV.fetch('PRUSA_ACCOUNT_TOKEN_URL', 'https://account.prusa3d.com/o/token/')
    # Public OAuth client id of the Connect web app (PKCE, no secret).
    CLIENT_ID = 'MRHTlZhZqkNrrQ6FUPtjyusAz8nc59ErHXP8XkS4'.freeze

    def initialize(credential: PrusaConnectCredential.current, timeout: DEFAULT_TIMEOUT)
      @credential = credential
      @timeout = timeout
    end

    def configured?
      @credential&.configured? || false
    end

    def printers
      get('/app/printers').fetch('printers', [])
    end

    def printer(uuid)
      get("/app/printers/#{uuid}")
    end

    def jobs(uuid)
      get("/app/printers/#{uuid}/jobs").fetch('jobs', [])
    end

    def notifications(limit: 20)
      get('/app/notifications', limit: limit).fetch('notifications', [])
    end

    private

    def get(path, params = {})
      raise AuthError, 'Prusa Connect refresh token is not configured' unless configured?

      uri = URI("#{BASE_URL}#{path}")
      uri.query = URI.encode_www_form(params) if params.any?
      response = authorized_get(uri)
      response = authorized_get(uri, force_refresh: true) if response.is_a?(Net::HTTPUnauthorized)
      parse(response, "GET #{path}")
    rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError, JSON::ParserError => e
      raise Error, "Prusa Connect request failed: #{e.class} #{e.message}"
    end

    def authorized_get(uri, force_refresh: false)
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{access_token(force_refresh: force_refresh)}"
      request['Accept'] = 'application/json'
      perform(uri, request)
    end

    def parse(response, label)
      case response
      when Net::HTTPSuccess then JSON.parse(response.body.presence || '{}')
      when Net::HTTPUnauthorized then raise AuthError, 'Prusa Connect rejected the access token'
      else raise Error, "Prusa Connect #{label} failed: #{response.code} #{response.message}"
      end
    end

    def access_token(force_refresh: false)
      return @credential.access_token if !force_refresh && @credential.access_token_fresh?

      refresh!
      @credential.access_token
    end

    def refresh!
      uri = URI(TOKEN_URL)
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(grant_type: 'refresh_token', refresh_token: @credential.refresh_token, client_id: CLIENT_ID)
      response = perform(uri, request)
      raise_refresh_failure!(response) unless response.is_a?(Net::HTTPSuccess)

      body = JSON.parse(response.body)
      @credential.store_tokens!(
        access_token: body.fetch('access_token'),
        expires_in: body['expires_in'] || 3600,
        refresh_token: body['refresh_token']
      )
    end

    def raise_refresh_failure!(response)
      message = "Prusa account token refresh failed: #{response.code} #{response.message}"
      @credential.record_error!(message)
      raise AuthError, message if [400, 401].include?(response.code.to_i)

      raise Error, message
    end

    def perform(uri, request)
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https',
                                              open_timeout: @timeout, read_timeout: @timeout) do |http|
        http.request(request)
      end
    end
  end
end
