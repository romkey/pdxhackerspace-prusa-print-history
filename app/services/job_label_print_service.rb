class JobLabelPrintService
  class Error < StandardError; end

  def self.call(job:, label_printer: nil)
    printer = label_printer || LabelPrinter.default
    raise Error, 'No label printer configured' if printer.nil?

    pdf = JobLabelPdf.new(job, thermal_width_mm: printer.thermal_roll_width_mm || 80)
    CupsService.print_data(
      pdf.render,
      printer.cups_printer_name,
      cups_printer_server: printer.cups_printer_server,
      filename: "job_label_#{job.id}.pdf",
      options: printer.cups_options
    )
  end
end
