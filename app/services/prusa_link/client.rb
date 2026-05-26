require 'json'
require 'net/http'
require 'uri'

module PrusaLink
  class Error < StandardError; end

  class Client
    DEFAULT_TIMEOUT = 5

    attr_reader :printer

    def initialize(printer, timeout: DEFAULT_TIMEOUT)
      @printer = printer
      @timeout = timeout
    end

    def status
      get('/api/v1/status')
    end

    def job
      get('/api/v1/job')
    rescue Error => e
      raise unless e.message.include?('204') || e.message.include?('404')

      nil
    end

    def info
      get('/api/v1/info')
    end

    private

    def get(path)
      uri = URI.join("http://#{@printer.hostname}", path)
      request = Net::HTTP::Get.new(uri)
      request['X-Api-Key'] = @printer.prusalink_key
      request['Accept']    = 'application/json'

      response = perform(uri, request)

      case response
      when Net::HTTPSuccess
        body = response.body.to_s
        body.empty? ? {} : JSON.parse(body)
      when Net::HTTPNoContent
        nil
      else
        raise Error, "PrusaLink GET #{path} failed: #{response.code} #{response.message}"
      end
    rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
      raise Error, "PrusaLink GET #{path} failed: #{e.class} #{e.message}"
    end

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
