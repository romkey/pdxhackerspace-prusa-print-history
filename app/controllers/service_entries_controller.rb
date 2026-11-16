class ServiceEntriesController < ApplicationController
  before_action :require_login_or_internal, only: %i[index new_problem create_problem]
  before_action :require_login,
                only: %i[new_repair create_repair resolve new_outage out_of_service return_to_service]

  def index
    @printer = printer_from_service_route
    @printers = Printer.ordered
    @listing = build_listing
    @pagy = build_pagy
    @entries = @listing.page(@pagy.page)
    @scores = PrinterReliability.all
    @open_counts = ServiceEntry.open.group(:printer_id).count
  end

  def new_problem
    build_form('problem')
  end

  def create_problem
    save_problem || render(:new_problem, status: :unprocessable_content)
  end

  def new_repair
    build_form('repair')
  end

  def create_repair
    save_repair || render(:new_repair, status: :unprocessable_content)
  end

  def resolve
    problem = ServiceEntry.find(params.expect(:id))
    PrinterServiceLog.resolve_problem!(problem, user: current_user)
    redirect_back_or_to service_log_path, notice: 'Resolved the problem report.'
  rescue PrinterServiceLog::Error, ActiveRecord::RecordInvalid => e
    redirect_back_or_to service_log_path, alert: e.message
  end

  def new_outage
    @printer = Printer.find(params.expect(:id))
    @entry = ServiceEntry.new(printer: @printer, kind: 'out_of_service')
  end

  def out_of_service
    @printer = Printer.find(params.expect(:id))
    PrinterServiceLog.take_out_of_service!(printer: @printer, user: current_user, reason: outage_reason)
    redirect_to service_printer_path(@printer), notice: "#{@printer.name} is out of service."
  rescue ActiveRecord::RecordInvalid => e
    @entry = e.record
    render :new_outage, status: :unprocessable_content
  rescue PrinterServiceLog::Error => e
    @entry = ServiceEntry.new(printer: @printer, kind: 'out_of_service', summary: outage_reason)
    flash.now[:alert] = e.message
    render :new_outage, status: :unprocessable_content
  end

  def return_to_service
    printer = Printer.find(params.expect(:id))
    PrinterServiceLog.return_to_service!(printer:, user: current_user, note: 'Back in service')
    redirect_to service_printer_path(printer), notice: "#{printer.name} is back in service."
  rescue PrinterServiceLog::Error => e
    redirect_to service_printer_path(printer), alert: e.message
  end

  private

  def save_problem
    printer = Printer.find(problem_params[:printer_id])
    already_out = printer.out_of_service?
    PrinterServiceLog.report_problem!(printer:, user: current_user, **problem_attributes)
    redirect_to service_printer_path(printer), notice: problem_notice(printer, already_out)
    true
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
    assign_problem_failure(e)
    false
  end

  def save_repair
    printer = Printer.find(repair_params[:printer_id])
    PrinterServiceLog.log_repair!(printer:, user: current_user, **repair_attributes)
    redirect_to service_printer_path(printer), notice: "Logged a repair on #{printer.name}."
    true
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid, PrinterServiceLog::Error => e
    assign_repair_failure(e)
    false
  end

  def problem_attributes
    {
      summary: problem_params[:summary],
      details: problem_params[:details],
      take_out_of_service: logged_in? && truthy?(problem_params[:take_out_of_service])
    }
  end

  def repair_attributes
    {
      summary: repair_params[:summary],
      details: repair_params[:details],
      occurred_at: repair_params[:occurred_at],
      resolves: resolve_ids,
      return_to_service: truthy?(repair_params[:return_to_service])
    }
  end

  def problem_notice(printer, already_out)
    return "Reported a problem on #{printer.name}." unless logged_in? && truthy?(problem_params[:take_out_of_service])
    return "Reported a problem on #{printer.name}. It was already out of service." if already_out

    "Reported a problem and took #{printer.name} out of service."
  end

  def assign_problem_failure(error)
    build_form('problem')
    return @entry.errors.add(:printer, 'must be chosen') if error.is_a?(ActiveRecord::RecordNotFound)

    @entry = error.record
  end

  def assign_repair_failure(error)
    build_form('repair')
    case error
    when ActiveRecord::RecordInvalid then @entry = error.record
    when ActiveRecord::RecordNotFound then @entry.errors.add(:printer, 'must be chosen')
    else
      @entry.assign_attributes(summary: repair_params[:summary], details: repair_params[:details])
      @entry.errors.add(:base, error.message)
    end
  end

  def build_form(kind)
    @printers = Printer.ordered
    @printer = Printer.find_by(id: params[:printer_id].presence || params.dig(:service_entry, :printer_id))
    @entry = ServiceEntry.new(printer: @printer, kind:)
    @open_problems = @printer ? @printer.service_entries.open.recent : ServiceEntry.none
  end

  def build_listing
    ServiceLogListing.new(
      printer: @printer, kind: params[:kind], state: params[:state], printer_id: params[:printer_id]
    )
  end

  def build_pagy
    Pagy::Offset.new(
      count: @listing.total_count, page: params[:page], limit: ServiceLogListing::PAGE_SIZE,
      request: Pagy::Request.new(request:)
    )
  end

  def printer_from_service_route
    return unless request.path.match?(%r{\A/printers/[^/]+/service\z})

    Printer.find(params.expect(:id))
  end

  def problem_params
    keys = %i[printer_id summary details]
    keys << :take_out_of_service if logged_in?
    params.expect(service_entry: keys)
  end

  def repair_params
    params.expect(service_entry: %i[printer_id summary details occurred_at return_to_service])
  end

  def outage_reason
    params.expect(service_entry: [:summary])[:summary]
  end

  def resolve_ids
    Array(params.dig(:service_entry, :resolves))
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
