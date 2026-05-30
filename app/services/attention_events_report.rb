class AttentionEventsReport
  Row = Data.define(:key, :label, :week_count, :month_count, :all_count)

  WEEK_WINDOW = 7.days
  MONTH_WINDOW = 30.days

  CHART_PERIODS = [
    ['Last 7 days', :week_count],
    ['Last 30 days', :month_count],
    ['All time', :all_count]
  ].freeze

  class << self
    def by_printer
      merge_rows(Printer.ordered, rows_from_sql(printer_sql))
    end

    def chart_series(rows, limit: 10)
      top_rows = chartable_rows(rows, limit)
      return [] if top_rows.empty?

      CHART_PERIODS.map do |label, accessor|
        { name: label, data: top_rows.map { |row| [row.label, row.public_send(accessor)] } }
      end
    end

    private

    def chartable_rows(rows, limit)
      rows.sort_by { |row| [-row.all_count, row.label.downcase] }
          .first(limit)
          .reject { |row| row.week_count.zero? && row.month_count.zero? && row.all_count.zero? }
    end

    def merge_rows(records, aggregate_rows, key = :id)
      aggregates = aggregate_rows.index_by(&:key)
      records.map do |record|
        record_key = record.public_send(key).to_s
        aggregates[record_key] || empty_row(record_key, record.name)
      end
    end

    def empty_row(key, label)
      Row.new(key:, label:, week_count: 0, month_count: 0, all_count: 0)
    end

    def rows_from_sql(sql)
      ActiveRecord::Base.connection.select_all(sql).map do |row|
        Row.new(
          key: row['key'].to_s,
          label: row['label'],
          week_count: row['week_count'].to_i,
          month_count: row['month_count'].to_i,
          all_count: row['all_count'].to_i
        )
      end
    end

    def period_counts
      week_cutoff = ActiveRecord::Base.connection.quote(WEEK_WINDOW.ago)
      month_cutoff = ActiveRecord::Base.connection.quote(MONTH_WINDOW.ago)

      <<~SQL.squish
        SUM(CASE WHEN job_events.occurred_at >= #{week_cutoff} THEN 1 ELSE 0 END) AS week_count,
        SUM(CASE WHEN job_events.occurred_at >= #{month_cutoff} THEN 1 ELSE 0 END) AS month_count,
        COUNT(*) AS all_count
      SQL
    end

    def printer_sql
      <<~SQL.squish
        SELECT printers.id::text AS key,
               printers.name AS label,
               #{period_counts}
        FROM job_events
        INNER JOIN jobs ON jobs.id = job_events.job_id
        INNER JOIN printers ON printers.id = jobs.printer_id
        WHERE job_events.event_type = 'attention'
        GROUP BY printers.id, printers.name
      SQL
    end
  end
end
