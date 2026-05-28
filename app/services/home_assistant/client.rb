require 'json'
require 'net/http'
require 'uri'

module HomeAssistant
  class Error < StandardError; end

  class Client
    DEFAULT_TIMEOUT = 5

    def self.from_env
      new(base_url: ENV.fetch('HOME_ASSISTANT_URL', nil),
          token: ENV.fetch('HOME_ASSISTANT_TOKEN', nil))
    end

    def initialize(base_url:, token:, timeout: DEFAULT_TIMEOUT)
      @base_url = base_url
      @token    = token
      @timeout  = timeout
    end

    def configured?
      @base_url.present? && @token.present?
    end

    def entity(entity_id)
      return nil if entity_id.blank? || !configured?

      get("/api/states/#{entity_id}")
    end

    def state(entity_id)
      entity(entity_id)&.fetch('state', nil)
    end

    def numeric_state(entity_id)
      raw = state(entity_id)
      return nil if raw.nil? || %w[unknown unavailable].include?(raw)

      Float(raw)
    rescue ArgumentError, TypeError
      nil
    end

    def temperature_celsius(entity_id)
      data = entity(entity_id)
      return nil if data.nil?

      raw = data['state']
      return nil if raw.nil? || %w[unknown unavailable].include?(raw)

      value = Float(raw)
      unit = data.dig('attributes', 'unit_of_measurement')
      Temperature.to_celsius(value, unit)
    rescue ArgumentError, TypeError
      nil
    end

    def available?
      return false unless configured?

      response = get('/api/')
      response.is_a?(Hash) && response['message'].to_s.include?('API running')
    rescue Error
      false
    end

    private

    def get(path)
      uri = URI.join(@base_url, path)
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{@token}"
      request['Content-Type']  = 'application/json'

      response = Net::HTTP.start(uri.hostname, uri.port,
                                 use_ssl: uri.scheme == 'https',
                                 open_timeout: @timeout,
                                 read_timeout: @timeout) do |http|
        http.request(request)
      end

      case response
      when Net::HTTPSuccess
        JSON.parse(response.body.to_s)
      when Net::HTTPNotFound
        nil
      else
        raise Error, "HomeAssistant GET #{path} failed: #{response.code} #{response.message}"
      end
    rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
      raise Error, "HomeAssistant GET #{path} failed: #{e.class} #{e.message}"
    end
  end
end
