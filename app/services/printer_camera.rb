require 'net/http'
require 'tempfile'
require 'uri'

class PrinterCamera
  DEFAULT_TIMEOUT = 5

  def self.snapshot(printer, timeout: DEFAULT_TIMEOUT)
    new(printer, timeout: timeout).snapshot
  end

  def initialize(printer, timeout: DEFAULT_TIMEOUT)
    @printer = printer
    @timeout = timeout
  end

  def snapshot
    return nil unless @printer.camera?

    response = fetch(@printer.camera_url)
    return nil unless response.is_a?(Net::HTTPSuccess)

    {
      io: StringIO.new(response.body.to_s.dup.force_encoding(Encoding::BINARY)),
      filename: filename_for(response),
      content_type: response['Content-Type'].presence || 'image/jpeg'
    }
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError, URI::InvalidURIError => e
    Rails.logger.warn("PrinterCamera failed for printer ##{@printer.id}: #{e.class}: #{e.message}")
    nil
  end

  private

  def fetch(url)
    uri = URI.parse(url)
    Net::HTTP.start(uri.hostname, uri.port,
                    use_ssl: uri.scheme == 'https',
                    open_timeout: @timeout,
                    read_timeout: @timeout) do |http|
      http.get(uri.request_uri)
    end
  end

  def filename_for(response)
    extension = case response['Content-Type'].to_s
                when /png/  then 'png'
                when /webp/ then 'webp'
                else 'jpg'
                end
    "printer_#{@printer.id}_#{Time.current.to_i}.#{extension}"
  end
end
