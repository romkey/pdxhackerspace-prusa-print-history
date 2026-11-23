# Reads a printer's firmware version and records it. The first reading and each change
# become a repair entry in the service log. A failed read leaves everything untouched.
class PrinterFirmwareCheck
  def self.call(printer, client: nil, connect: nil)
    new(printer, client:, connect:).call
  end

  def initialize(printer, client: nil, connect: nil)
    @printer = printer
    @client = client
    @connect = connect
  end

  def call
    versions = read_versions
    return nil if versions.blank?

    record(versions)
    versions['printer']
  end

  private

  def record(versions)
    known = @printer.firmware_components.presence || { 'printer' => @printer.firmware_version }.compact
    initial = versions.reject { |component, _| known.key?(component) }
    changed = versions.select { |c, v| known.key?(c) && known[c] != v }.to_h { |c, v| [c, [known[c], v]] }
    Printer.transaction do
      @printer.update!(firmware_checked_at: Time.current, firmware_components: known.merge(versions),
                       firmware_version: versions['printer'] || @printer.firmware_version)
      PrinterServiceLog.log_firmware_changes!(printer: @printer, initial:, changed:)
    end
  end

  def read_versions
    from_connection.presence || from_connect.presence
  end

  def from_connection
    return nil unless @printer.connection_configured?

    client = @client || @printer.connection_client
    versions = @printer.bambu? ? client.firmware_versions : { 'printer' => client.version&.dig('firmware') }
    versions.transform_values { |v| v.to_s.strip }.compact_blank
  rescue PrinterConnection::Error => e
    Rails.logger.info("[PrinterFirmwareCheck] printer ##{@printer.id}: #{e.message}")
    nil
  end

  def from_connect
    return nil unless @printer.prusa_connect_api?

    api = @connect || PrusaConnect::ApiClient.new
    version = api.printer(@printer.prusa_connect_uuid)['firmware'].to_s.strip
    version.present? ? { 'printer' => version } : nil
  rescue PrusaConnect::Error => e
    Rails.logger.info("[PrinterFirmwareCheck] Connect, printer ##{@printer.id}: #{e.message}")
    nil
  end
end
