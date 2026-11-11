require 'net/http'
require 'uri'

class PrinterCamera
  DEFAULT_TIMEOUT = 5

  def self.snapshot(printer, client: nil, timeout: DEFAULT_TIMEOUT)
    new(printer, client: client, timeout: timeout).snapshot
  end

  def initialize(printer, client: nil, timeout: DEFAULT_TIMEOUT)
    @printer = printer
    @client = client
    @timeout = timeout
  end

  def snapshot
    snapshot_from_url || snapshot_from_printer
  end

  private

  def snapshot_from_url
    return nil unless @printer.camera?

    response = fetch(@printer.camera_url)
    return nil unless response.is_a?(Net::HTTPSuccess)

    build_snapshot(response.body.to_s, response['Content-Type'])
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError, URI::InvalidURIError => e
    log_failure(e)
    nil
  end

  def snapshot_from_printer
    return nil unless @printer.connection_configured?

    client = @client || @printer.connection_client
    body = client.camera_snapshot
    return nil if body.blank?

    build_snapshot(body, content_type_for(body))
  rescue PrinterConnection::Error => e
    log_failure(e)
    nil
  end

  def content_type_for(body)
    bytes = body.to_s.b
    return 'image/jpeg' if bytes.start_with?("\xFF\xD8".b)
    return 'image/png' if bytes.start_with?("\x89PNG".b)

    'image/png'
  end

  def fetch(url)
    uri = URI.parse(url)
    Net::HTTP.start(uri.hostname, uri.port,
                    use_ssl: uri.scheme == 'https',
                    open_timeout: @timeout,
                    read_timeout: @timeout) do |http|
      request = Net::HTTP::Get.new(uri)
      request.basic_auth(uri.user, uri.password) if uri.user.present?
      http.request(request)
    end
  end

  def build_snapshot(body, content_type)
    {
      io: StringIO.new(body.dup.force_encoding(Encoding::BINARY)),
      filename: filename_for(content_type),
      content_type: content_type.presence || 'image/jpeg'
    }
  end

  def filename_for(content_type)
    extension = case content_type.to_s
                when /png/  then 'png'
                when /webp/ then 'webp'
                else 'jpg'
                end
    "printer_#{@printer.id}_#{Time.current.to_i}.#{extension}"
  end

  def log_failure(error)
    Rails.logger.warn("PrinterCamera failed for printer ##{@printer.id}: #{error.class}: #{error.message}")
  end
end
