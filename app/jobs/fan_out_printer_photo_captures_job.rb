class FanOutPrinterPhotoCapturesJob < ApplicationJob
  queue_as :default

  def perform
    Printer.find_each do |printer|
      next unless printer.capture_photos?

      PrinterPhotoCaptureJob.perform_later(printer.id)
    end
  end
end
