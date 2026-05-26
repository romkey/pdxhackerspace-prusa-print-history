class FanOutPrinterPhotoCapturesJob < ApplicationJob
  queue_as :default

  def perform
    Printer.find_each do |printer|
      next unless printer.camera? || printer.prusalink?

      PrinterPhotoCaptureJob.perform_later(printer.id)
    end
  end
end
