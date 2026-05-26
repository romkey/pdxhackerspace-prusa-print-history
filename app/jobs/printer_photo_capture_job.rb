class PrinterPhotoCaptureJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(printer_id)
    printer = Printer.find(printer_id)
    PrinterPhotoCapture.capture!(printer, job: printer.current_job)
  end
end
