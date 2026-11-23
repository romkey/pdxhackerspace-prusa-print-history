class PrinterFirmwareCheckJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(printer_id)
    PrinterFirmwareCheck.call(Printer.find(printer_id))
  end
end
