class FanOutPrinterPollsJob < ApplicationJob
  queue_as :default

  def perform
    Printer.where.not(prusalink_key: nil).find_each do |printer|
      PrinterPollJob.perform_later(printer.id)
    end
  end
end
