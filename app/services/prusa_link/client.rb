require 'json'
require 'net/http'
require 'uri'

module PrusaLink
  class Error < PrinterConnection::Error; end

  class Client
    DEFAULT_TIMEOUT = 5
    UPLOAD_TIMEOUT = 300
    UPLOAD_STORAGE = 'usb'.freeze

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

    def pause_job(job_id)
      send_command(Net::HTTP::Put, "/api/v1/job/#{job_id}/pause")
    end

    def resume_job(job_id)
      send_command(Net::HTTP::Put, "/api/v1/job/#{job_id}/resume")
    end

    def stop_job(job_id)
      send_command(Net::HTTP::Delete, "/api/v1/job/#{job_id}")
    end

    # Uploads a G-code file to the printer's storage and, when +print+ is true, starts it.
    # +io+ is streamed, so large files are never read into memory.
    def upload_file(io, filename:, size:, storage: UPLOAD_STORAGE, print: true)
      path = "/api/v1/files/#{storage}/#{ERB::Util.url_encode(filename)}"
      uri = URI.join("http://#{@printer.hostname}", path)
      request = Net::HTTP::Put.new(uri)
      request['X-Api-Key'] = @printer.prusalink_key
      request['Content-Type'] = 'application/octet-stream'
      request['Content-Length'] = size.to_s
      request['Overwrite'] = '?1'
      request['Print-After-Upload'] = '?1' if print
      request.body_stream = io

      response = perform(uri, request, read_timeout: UPLOAD_TIMEOUT)
      return true if response.is_a?(Net::HTTPSuccess)

      raise Error, "PrusaLink PUT #{path} failed: #{response.code} #{response.message}"
    rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
      raise Error, "PrusaLink PUT #{path} failed: #{e.class} #{e.message}"
    end

    private

    def send_command(request_class, path)
      uri = URI.join("http://#{@printer.hostname}", path)
      request = request_class.new(uri)
      request['X-Api-Key'] = @printer.prusalink_key

      response = perform(uri, request)
      return true if response.is_a?(Net::HTTPSuccess)

      raise Error, "PrusaLink #{request.method} #{path} failed: #{response.code} #{response.message}"
    rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
      raise Error, "PrusaLink #{request.method} #{path} failed: #{e.class} #{e.message}"
    end

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

    def perform(uri, request, read_timeout: @timeout)
      Net::HTTP.start(uri.hostname, uri.port,
                      use_ssl: uri.scheme == 'https',
                      open_timeout: @timeout,
                      read_timeout: read_timeout) do |http|
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
