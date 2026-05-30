class EventListing
  PAGE_SIZE = 20

  FILTER_EVENT_TYPES = {
    'start' => { source: :job, types: %w[started] },
    'end' => { source: :job, types: %w[finished] },
    'attention' => { source: :job, types: %w[attention] },
    'filament_change' => { source: :printer, types: %w[filament_change] }
  }.freeze

  Row = Data.define(:source_type, :source_id, :occurred_at, :record)

  def initialize(filters:)
    @filters = Array(filters).map(&:to_s) & FILTER_EVENT_TYPES.keys
  end

  attr_reader :filters

  def results(page: 1)
    entries, = fetch_page(page)
    load_records(entries)
  end

  def total_count
    union_sql = union_query_sql
    return 0 if union_sql.blank?

    ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM (#{union_sql}) AS all_events").to_i
  end

  private

  def fetch_page(page)
    page = normalized_page(page)
    union_sql = union_query_sql
    return [[], 0] if union_sql.blank?

    rows = query_page_rows(union_sql, page)
    entries = rows.map { |row| row_entry(row) }

    [entries, total_count]
  end

  def normalized_page(page)
    [page.to_i, 1].max
  end

  def query_page_rows(union_sql, page)
    offset = (page - 1) * PAGE_SIZE
    ActiveRecord::Base.connection.select_all(
      <<~SQL.squish
        SELECT source_type, source_id, occurred_at
        FROM (#{union_sql}) AS all_events
        ORDER BY occurred_at DESC
        LIMIT #{PAGE_SIZE} OFFSET #{offset}
      SQL
    ).to_a
  end

  def row_entry(row)
    Row.new(
      source_type: row['source_type'],
      source_id: row['source_id'].to_i,
      occurred_at: row['occurred_at'],
      record: nil
    )
  end

  def union_query_sql
    parts = []
    parts << job_events_relation.to_sql if include_job_events?
    parts << printer_events_relation.to_sql if include_printer_events?
    return if parts.empty?

    parts.join(' UNION ALL ')
  end

  def include_job_events?
    @filters.empty? || @filters.any? { |filter| FILTER_EVENT_TYPES.fetch(filter)[:source] == :job }
  end

  def include_printer_events?
    @filters.empty? || @filters.any? { |filter| FILTER_EVENT_TYPES.fetch(filter)[:source] == :printer }
  end

  def job_event_types
    return JobEvent::EVENT_TYPES if @filters.empty?

    @filters.flat_map { |filter| FILTER_EVENT_TYPES.dig(filter, :types) }.compact.uniq
  end

  def printer_event_types
    return PrinterEvent::EVENT_TYPES if @filters.empty?

    @filters.flat_map do |filter|
      next unless FILTER_EVENT_TYPES.fetch(filter)[:source] == :printer

      FILTER_EVENT_TYPES.fetch(filter)[:types]
    end.compact.uniq
  end

  def job_events_relation
    JobEvent
      .joins(:job)
      .where(event_type: job_event_types)
      .select("'JobEvent' AS source_type", 'job_events.id AS source_id', 'job_events.occurred_at AS occurred_at')
  end

  def printer_events_relation
    PrinterEvent
      .where(event_type: printer_event_types)
      .select(
        "'PrinterEvent' AS source_type",
        'printer_events.id AS source_id',
        'printer_events.occurred_at AS occurred_at'
      )
  end

  def load_records(entries)
    job_ids = entries.select { |entry| entry.source_type == 'JobEvent' }.map(&:source_id)
    printer_ids = entries.select { |entry| entry.source_type == 'PrinterEvent' }.map(&:source_id)

    job_events = JobEvent
                 .where(id: job_ids)
                 .includes(job: :printer, photo_attachment: :blob)
                 .index_by(&:id)
    printer_events = PrinterEvent.where(id: printer_ids).includes(:printer).index_by(&:id)

    entries.map do |entry|
      record = if entry.source_type == 'JobEvent'
                 job_events[entry.source_id]
               else
                 printer_events[entry.source_id]
               end

      entry.with(record: record)
    end
  end
end
