class PrintersController < ApplicationController
  before_action :require_admin, only: %i[new create edit update destroy]
  before_action :set_printer, only: %i[show edit update destroy camera]

  def index
    @printers = Printer.ordered
  end

  def show
    @presenter = PrinterShowPresenter.new(@printer)
  end

  def camera
    snapshot = PrinterCamera.snapshot(@printer)
    return head :service_unavailable if snapshot.nil?

    send_data snapshot[:io].read,
              type: snapshot[:content_type],
              disposition: 'inline',
              filename: snapshot[:filename]
  end

  def new
    @printer = Printer.new
  end

  def edit; end

  def create
    @printer = Printer.new(printer_params)
    if @printer.save
      redirect_to @printer, notice: "Added #{@printer.name}."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @printer.update(printer_params)
      redirect_to @printer, notice: "Saved changes to #{@printer.name}."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @printer.destroy
    redirect_to printers_path, notice: "Removed #{@printer.name}."
  end

  private

  def set_printer
    @printer = Printer.find(params.expect(:id))
  end

  def printer_params
    permitted = params.expect(printer: %i[name location model hostname
                                          prusalink_key ha_base_sensor camera_url])
    permitted[:prusalink_key] = nil if permitted[:prusalink_key].blank? && action_name == 'update'
    permitted.delete(:prusalink_key) if permitted[:prusalink_key].blank? && action_name == 'update'
    permitted
  end
end
