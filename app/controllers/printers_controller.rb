class PrintersController < ApplicationController
  before_action :require_login_or_internal, only: %i[index show camera]
  before_action :require_admin, only: %i[new create edit update destroy pause resume stop submit]
  before_action :set_printer, only: %i[show edit update destroy camera pause resume stop submit]

  def index
    @printers = Printer.ordered
  end

  def show
    @presenter = PrinterShowPresenter.new(@printer)
  end

  def camera
    # The stored captures and the live snapshot both show whatever is on the bed.
    return head :forbidden unless job_details_visible?(@printer.latest_job)

    if (capture = stored_capture)
      return send_capture(capture)
    end

    snapshot = PrinterCamera.snapshot(@printer)
    return head :service_unavailable if snapshot.nil?

    send_data snapshot[:io].read,
              type: snapshot[:content_type],
              disposition: 'inline',
              filename: snapshot[:filename]
  end

  def submit
    file = params[:gcode]
    return redirect_to @printer, alert: 'Choose a file to print.' unless file.respond_to?(:tempfile)

    name = PrinterControl.new(@printer).submit(file)
    redirect_to @printer, notice: "Submitted #{name} to #{@printer.name}."
  rescue PrinterControl::NotAllowed, PrinterConnection::Error => e
    redirect_to @printer, alert: e.message
  end

  def pause
    run_control(:pause, 'Pause requested')
  end

  def resume
    run_control(:resume, 'Resume requested')
  end

  def stop
    run_control(:stop, 'Stop requested')
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

  def run_control(action, success)
    PrinterControl.new(@printer).public_send(action)
    redirect_to @printer, notice: "#{success} for #{@printer.name}."
  rescue PrinterControl::NotAllowed, PrinterConnection::Error => e
    redirect_to @printer, alert: e.message
  end

  def stored_capture
    capture = @printer.photo_captures.reverse_chronological.includes(image_attachment: :blob).first
    capture if capture&.image&.attached?
  end

  def send_capture(capture)
    send_data capture.image.download,
              type: capture.image.content_type,
              disposition: 'inline',
              filename: capture.image.filename.to_s
  end

  def set_printer
    @printer = Printer.find(params.expect(:id))
  end

  def printer_params
    permitted = params.expect(printer: %i[name location model hostname printer_type
                                          prusalink_key prusa_connect_token prusa_connect_uuid
                                          bambu_serial bambu_access_code
                                          ha_base_sensor camera_url])
    clear_blank_secret(permitted, :prusalink_key)
    clear_blank_secret(permitted, :prusa_connect_token)
    clear_blank_secret(permitted, :bambu_access_code)
    permitted
  end

  def clear_blank_secret(permitted, key)
    permitted.delete(key) if action_name == 'update' && permitted[key].blank?
  end
end
