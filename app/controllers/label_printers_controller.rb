class LabelPrintersController < ApplicationController
  before_action :require_admin
  before_action :set_label_printer, only: %i[edit update destroy test_print]

  def index
    @label_printers = LabelPrinter.ordered
    @cups_printers = CupsService.available_printers
  end

  def new
    @label_printer = LabelPrinter.new
    @cups_printers = CupsService.available_printers
  end

  def edit
    @cups_printers = CupsService.available_printers
  end

  def create
    @label_printer = LabelPrinter.new(label_printer_params)
    if @label_printer.save
      redirect_to label_printers_path, notice: 'Label printer added.'
    else
      @cups_printers = CupsService.available_printers
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @label_printer.update(label_printer_params)
      redirect_to label_printers_path, notice: 'Label printer updated.'
    else
      @cups_printers = CupsService.available_printers
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @label_printer.destroy!
    redirect_to label_printers_path, notice: 'Label printer removed.'
  end

  def test_print
    job_id = CupsService.test_print(
      @label_printer.cups_printer_name,
      cups_printer_server: @label_printer.cups_printer_server
    )
    redirect_to label_printers_path, notice: "Test page sent to #{@label_printer.name} (job #{job_id})."
  rescue CupsService::PrintError => e
    redirect_to label_printers_path, alert: "Test print failed: #{e.message}"
  end

  private

  def set_label_printer
    @label_printer = LabelPrinter.find(params.expect(:id))
  end

  def label_printer_params
    permitted = params.expect(
      label_printer: %i[
        name cups_printer_server cups_printer_name description default_printer position thermal_roll_width_mm
      ]
    )
    permitted[:thermal_roll_width_mm] = permitted[:thermal_roll_width_mm].presence&.to_i
    permitted
  end
end
