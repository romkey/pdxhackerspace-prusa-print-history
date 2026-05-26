class PrinterPollJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(printer_id)
    printer = Printer.find(printer_id)
    PrinterPoller.new(printer).poll!
  end
end
