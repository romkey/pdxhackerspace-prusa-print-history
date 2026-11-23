class FanOutPrinterFirmwareChecksJob < ApplicationJob
  queue_as :default

  def perform
    Printer.find_each do |printer|
      PrinterFirmwareCheckJob.perform_later(printer.id) if printer.connection_configured? || printer.prusa_connect_api?
    end
  end
end
