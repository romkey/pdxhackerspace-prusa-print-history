module ServiceEntriesHelper
  KIND_LABELS = {
    'problem' => 'Problem',
    'repair' => 'Repair',
    'out_of_service' => 'Out of service',
    'back_in_service' => 'Back in service'
  }.freeze

  KIND_FILTERS = {
    'problem' => 'Problems',
    'repair' => 'Repairs',
    'status' => 'Status changes'
  }.freeze

  STATE_FILTERS = {
    'open' => 'Open',
    'resolved' => 'Resolved'
  }.freeze

  def service_kind_filters = KIND_FILTERS
  def service_state_filters = STATE_FILTERS

  def service_entry_kind_label(entry)
    KIND_LABELS.fetch(entry.kind, entry.kind.humanize)
  end

  def service_entry_dot_class(entry)
    entry.open_problem? ? 'status-warning' : 'status-muted'
  end

  def service_entry_author(entry)
    entry.user&.display_name || 'Shop visitor'
  end

  def service_filter_href(key, value, printer)
    current = { kind: params[:kind].presence, state: params[:state].presence }
    current[:printer_id] = params[:printer_id].presence if printer.nil?
    current[key] = current[key].to_s == value.to_s ? nil : value
    service_log_location(printer, current.compact_blank)
  end

  def service_filter_chip_class(key, value)
    classes = ['filter-chip']
    classes << 'active' if params[key].to_s == value.to_s
    classes.join(' ')
  end

  def service_log_location(printer, extra = {})
    return service_printer_path(printer, **extra) if printer

    service_log_path(**extra)
  end

  def relative_timestamp(time)
    zone_time = time.in_time_zone
    date = zone_time.to_date
    today = Time.zone.today
    relative_timestamp_label(zone_time, date, today)
  end

  def reliability_score_class(score)
    return 'text-secondary' if score.nil?
    return 'text-danger' if score < 50
    return 'text-warning' if score < 80

    ''
  end

  def reliability_count(count, noun)
    css = count.to_i.zero? ? 'text-secondary' : 'text-body'
    tag.span(pluralize(count.to_i, noun), class: css)
  end

  def resolve_checked?(problem)
    ids = params.dig(:service_entry, :resolves)
    return true if ids.nil?

    Array(ids).map(&:to_s).include?(problem.id.to_s)
  end

  private

  def relative_timestamp_label(zone_time, date, today)
    if date == today then l(zone_time, format: :time_only)
    elsif date == today - 1 then 'Yesterday'
    elsif date > today - 7 then "#{time_ago_in_words(zone_time)} ago"
    elsif date.year == today.year then l(zone_time, format: :month_day)
    else
      l(zone_time, format: :month_day_year)
    end
  end
end
