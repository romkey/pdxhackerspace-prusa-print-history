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

    def legacy_printer
      get('/api/printer')
    rescue Error => e
      raise unless e.message.include?('404')

      nil
    end

    def file_info(storage_path)
      return nil if storage_path.blank?

      storage, path = split_storage_path(storage_path)
      return nil if storage.blank? || path.blank?

      get("/api/v1/files/#{storage}#{path}")
    rescue Error => e
      raise unless e.message.include?('404')

      nil
    end

    def download(path)
      return nil if path.blank?

      binary_get(path)
    end

    def camera_snapshot
      binary_get('/api/v1/cameras/snap')
    rescue Error => e
      raise unless camera_unavailable?(e)

      nil
    end

    private

    def binary_get(path)
      uri = URI.join("http://#{@printer.hostname}", path)
      request = Net::HTTP::Get.new(uri)
      request['X-Api-Key'] = @printer.prusalink_key

      response = perform(uri, request)

      case response
      when Net::HTTPSuccess
        body = response.body.to_s
        ResponseLogger.log_binary!(printer: @printer, path: path, byte_size: body.bytesize)
        body.empty? ? nil : body.b
      else
        raise Error, "PrusaLink GET #{path} failed: #{response.code} #{response.message}"
      end
    rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
      raise Error, "PrusaLink GET #{path} failed: #{e.class} #{e.message}"
    end

    def camera_unavailable?(error)
      error.message.match?(/\b(204|404|503)\b/)
    end

    def get(path)
      uri = URI.join("http://#{@printer.hostname}", path)
      request = Net::HTTP::Get.new(uri)
      request['X-Api-Key'] = @printer.prusalink_key
      request['Accept']    = 'application/json'

      response = perform(uri, request)

      case response
      when Net::HTTPSuccess
        body = response.body.to_s
        parsed = body.empty? ? {} : JSON.parse(body)
        ResponseLogger.log_json!(printer: @printer, path: path, payload: parsed)
        parsed
      when Net::HTTPNoContent
        ResponseLogger.log_json!(printer: @printer, path: path, payload: nil)
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

    def split_storage_path(storage_path)
      normalized = storage_path.to_s.strip
      normalized = normalized.delete_prefix('/')
      storage, path = normalized.split('/', 2)
      path = "/#{path}" if path.present? && !path.start_with?('/')
      [storage, path]
    end
  end
end
