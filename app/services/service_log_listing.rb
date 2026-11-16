class ServiceLogListing
  PAGE_SIZE = 50

  KIND_FILTERS = {
    'problem' => %w[problem],
    'repair' => %w[repair],
    'status' => %w[out_of_service back_in_service]
  }.freeze

  STATE_FILTERS = %w[open resolved].freeze

  def initialize(printer: nil, kind: nil, state: nil, printer_id: nil)
    @printer = printer
    @kind = KIND_FILTERS.key?(kind.to_s) ? kind.to_s : nil
    @state = STATE_FILTERS.include?(state.to_s) ? state.to_s : nil
    @printer_filter = printer ? nil : Printer.find_by(id: printer_id)
  end

  attr_reader :printer, :kind, :state, :printer_filter

  def page(number)
    relation.offset((normalized(number) - 1) * PAGE_SIZE).limit(PAGE_SIZE)
  end

  def total_count
    relation.except(:includes, :order).count
  end

  def filter_count
    [kind, state, printer_filter].compact.size
  end

  def open_problem_count
    scope = ServiceEntry.open
    scope = scope.where(printer:) if printer
    scope.count
  end

  def out_of_service_count
    scope = Printer.where.not(out_of_service_since: nil)
    scope = scope.where(id: printer.id) if printer
    scope.count
  end

  private

  def relation
    scope = ServiceEntry.includes(:printer, :user, :resolved_by).recent
    scope = scope.where(printer_id: target_printer_id) if target_printer_id
    scope = scope.where(kind: KIND_FILTERS.fetch(kind)) if kind
    apply_state(scope)
  end

  def apply_state(scope)
    case state
    when 'open' then scope.merge(ServiceEntry.open)
    when 'resolved' then scope.merge(ServiceEntry.resolved)
    else scope
    end
  end

  def target_printer_id
    printer&.id || printer_filter&.id
  end

  def normalized(number)
    [number.to_i, 1].max
  end
end
