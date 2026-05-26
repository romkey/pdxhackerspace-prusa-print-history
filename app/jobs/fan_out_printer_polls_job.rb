class FanOutPrinterPollsJob < ApplicationJob
  queue_as :default

  def perform
    Printer.find_each do |printer|
      PrinterPollJob.perform_later(printer.id) if printer.prusalink?
    end
  end
end
