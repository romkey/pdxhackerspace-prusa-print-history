require 'net/http'
require 'uri'

module PrusaConnect
  class Client
    DEFAULT_TIMEOUT = 10
    SNAPSHOT_URL = ENV.fetch('PRUSA_CONNECT_SNAPSHOT_URL', 'https://webcam.connect.prusa3d.com/c/snapshot')
    MAX_BODY_SIZE = 16.megabytes

    def initialize(printer, timeout: DEFAULT_TIMEOUT, snapshot_url: SNAPSHOT_URL)
      @printer = printer
      @timeout = timeout
      @snapshot_url = snapshot_url
    end

    def upload_snapshot(body, content_type: 'image/jpeg')
      raise RateLimited, 'image exceeds 16 MB limit' if body.bytesize > MAX_BODY_SIZE

      uri = URI(@snapshot_url)
      request = Net::HTTP::Put.new(uri)
      request['Token'] = @printer.prusa_connect_token
      request['Fingerprint'] = @printer.prusa_connect_fingerprint
      request['Content-Type'] = content_type
      request.body = body

      response = perform(uri, request)

      case response
      when Net::HTTPSuccess
        true
      when Net::HTTPTooManyRequests
        raise RateLimited, "Prusa Connect rate limited: #{response.code}"
      else
        raise Error, "Prusa Connect PUT snapshot failed: #{response.code} #{response.message}"
      end
    rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
      raise Error, "Prusa Connect PUT snapshot failed: #{e.class} #{e.message}"
    end

    private

    def perform(uri, request)
      Net::HTTP.start(uri.hostname, uri.port,
                      use_ssl: uri.scheme == 'https',
                      open_timeout: @timeout,
                      read_timeout: @timeout) do |http|
        http.request(request)
      end
    end
  end
end
