class PrinterServiceLog
  class Error < StandardError; end

  FIRMWARE_LABELS = { 'printer' => 'Printer', 'th' => 'Toolhead', 'mc' => 'Motion controller' }.freeze

  def self.report_problem!(printer:, user:, summary:, details: nil, take_out_of_service: false)
    new.report_problem!(printer:, user:, summary:, details:, take_out_of_service:)
  end

  def self.log_repair!(printer:, user:, **attributes)
    new.log_repair!(printer:, user:, **attributes)
  end

  def self.log_firmware_changes!(printer:, initial:, changed:)
    new.log_firmware_changes!(printer:, initial:, changed:)
  end

  def self.resolve_problem!(...) = new.resolve_problem!(...)
  def self.take_out_of_service!(...) = new.take_out_of_service!(...)
  def self.return_to_service!(...) = new.return_to_service!(...)

  def report_problem!(printer:, user:, summary:, details: nil, take_out_of_service: false)
    ServiceEntry.transaction do
      entry = write_entry(printer, user, 'problem', summary:, details:, occurred_at: Time.current)
      take_out_for_problem!(printer, user, summary) if take_out_of_service
      entry
    end
  end

  def log_repair!(printer:, user:, **attributes)
    raise Error, 'Sign in to log a repair.' if user.blank?

    ServiceEntry.transaction do
      repair = write_entry(printer, user, 'repair', **repair_fields(attributes))
      resolve_selected!(repair, printer, user, attributes[:resolves])
      return_from_repair!(printer, user, attributes)
      repair
    end
  end

  # Automatic repair entries (no user) for firmware readings. `initial` is { component => version }
  # seen for the first time (one grouped entry); `changed` is { component => [old, new] }.
  def log_firmware_changes!(printer:, initial:, changed:)
    ServiceEntry.transaction do
      write_initial_firmware!(printer, initial) if initial.any?
      changed.each do |component, (old, new)|
        write_entry(printer, nil, 'repair', summary: "#{firmware_label(component)} firmware updated: #{old} → #{new}",
                                            occurred_at: Time.current, automatic: true)
      end
    end
  end

  def resolve_problem!(problem, user:)
    raise Error, 'Sign in to resolve a problem report.' if user.blank?
    raise Error, 'Only an open problem report can be resolved.' unless problem.open_problem?

    close_problem!(problem, user:)
  end

  def take_out_of_service!(printer:, user:, reason:)
    raise Error, 'Sign in to take a printer out of service.' if user.blank?
    raise Error, "#{printer.name} is already out of service." if printer.out_of_service?

    record_outage!(printer, user, 'out_of_service', reason) { |at| printer.update!(out_of_service_since: at) }
  end

  def return_to_service!(printer:, user:, note:)
    raise Error, 'Sign in to return a printer to service.' if user.blank?
    raise Error, "#{printer.name} is already in service." unless printer.out_of_service?

    record_outage!(printer, user, 'back_in_service', note.presence || 'Back in service') do
      printer.update!(out_of_service_since: nil)
    end
  end

  private

  def write_initial_firmware!(printer, initial)
    summary = if initial.size == 1 && initial.key?('printer')
                "Firmware #{initial['printer']} (initial reading)"
              else
                "Firmware initial reading: #{initial.map do |c, v|
                  "#{firmware_label(c)} #{v}"
                end.join(', ')}".truncate(200)
              end
    details = initial.map { |c, v| "#{firmware_label(c)}: #{v}" }.join("\n")
    write_entry(printer, nil, 'repair', summary:, details: "First firmware readings from the printer.\n#{details}",
                                        occurred_at: Time.current, automatic: true)
  end

  def firmware_label(component)
    return FIRMWARE_LABELS[component] if FIRMWARE_LABELS.key?(component)
    return "AMS #{component.split('/').last}" if component.start_with?('ams/')

    component
  end

  def take_out_for_problem!(printer, user, summary)
    return if user.blank? || printer.out_of_service?

    take_out_of_service!(printer:, user:, reason: summary)
  end

  def record_outage!(printer, user, kind, summary)
    ServiceEntry.transaction do
      occurred_at = Time.current
      yield occurred_at
      write_entry(printer, user, kind, summary:, details: nil, occurred_at:)
    end
  end

  def resolve_selected!(repair, printer, user, ids)
    selected = Array(ids).filter_map { |id| Integer(id, exception: false) }.uniq.reject(&:zero?)
    return if selected.empty?

    problems = printer.service_entries.open.where(id: selected).to_a
    raise Error, 'Choose open problem reports for this printer.' unless problems.size == selected.size

    problems.each { |problem| close_problem!(problem, user:, repair:) }
  end

  def close_problem!(problem, user:, repair: nil)
    problem.update!(resolved_at: Time.current, resolved_by: user, resolving_repair: repair)
  end

  def return_from_repair!(printer, user, attributes)
    return unless attributes[:return_to_service] && printer.out_of_service?

    return_to_service!(printer:, user:, note: attributes[:summary])
  end

  def repair_fields(attributes)
    attributes.slice(:summary, :details, :occurred_at)
  end

  def write_entry(printer, user, kind, **fields)
    ServiceEntry.create!(
      printer:, user:, kind:,
      summary: fields[:summary].to_s.strip,
      details: fields[:details].to_s.strip.presence,
      occurred_at: parse_time(fields[:occurred_at]),
      automatic: fields[:automatic] == true
    )
  end

  def parse_time(value)
    return Time.current if value.blank?
    return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    parsed = Time.zone.parse(value.to_s)
    raise Error, 'Enter a valid date and time.' if parsed.nil?

    parsed
  end
end
