class PrintersController < ApplicationController
  before_action :require_admin, only: %i[new create edit update destroy]
  before_action :set_printer,   only: %i[show edit update destroy]

  def index
    @printers = Printer.ordered
  end

  def show
    @recent_jobs    = @printer.jobs.recent.includes(:owner).limit(10)
    @current_job    = @printer.current_job
    @latest_reading = latest_reading_for(@current_job)
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

  def latest_reading_for(job)
    return nil if job.nil?

    job.telemetry_readings.reorder(recorded_at: :desc).first
  end

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
