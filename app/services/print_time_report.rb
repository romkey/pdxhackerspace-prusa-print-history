class PrintTimeReport
  Row = Data.define(:key, :label, :week_seconds, :month_seconds, :all_seconds)

  WEEK_WINDOW = 7.days
  MONTH_WINDOW = 30.days

  class << self
    def by_printer
      merge_rows(Printer.ordered, rows_from_sql(printer_sql))
    end

    def by_user
      merge_rows(User.alphabetical, rows_from_sql(user_sql))
    end

    def by_filament
      rows_from_sql(filament_sql)
    end

    def chart_series(rows, limit: 10)
      rows.sort_by { |row| [-row.all_seconds, row.label.downcase] }
          .first(limit)
          .filter_map { |row| chart_row(row) }
    end

    private

    def chart_row(row)
      return if row.week_seconds.zero? && row.month_seconds.zero? && row.all_seconds.zero?

      [
        row.label,
        [
          ['Last 7 days', hours(row.week_seconds)],
          ['Last 30 days', hours(row.month_seconds)],
          ['All time', hours(row.all_seconds)]
        ]
      ]
    end

    def hours(seconds)
      (seconds / 3600.0).round(2)
    end

    def merge_rows(records, aggregate_rows, key = :id)
      aggregates = aggregate_rows.index_by(&:key)
      records.map do |record|
        record_key = record.public_send(key).to_s
        aggregates[record_key] || empty_row(record_key, record_label(record))
      end
    end

    def record_label(record)
      case record
      when Printer then record.name
      when User then record.display_name
      else record.to_s
      end
    end

    def empty_row(key, label)
      Row.new(key:, label:, week_seconds: 0, month_seconds: 0, all_seconds: 0)
    end

    def rows_from_sql(sql)
      ActiveRecord::Base.connection.select_all(sql).map do |row|
        Row.new(
          key: row['key'].to_s,
          label: row['label'],
          week_seconds: row['week_seconds'].to_i,
          month_seconds: row['month_seconds'].to_i,
          all_seconds: row['all_seconds'].to_i
        )
      end
    end

    def period_sums(table_alias)
      week_cutoff = connection.quote(WEEK_WINDOW.ago)
      month_cutoff = connection.quote(MONTH_WINDOW.ago)
      duration = duration_expression(table_alias)

      <<~SQL.squish
        SUM(CASE WHEN #{table_alias}.ended_at >= #{week_cutoff} THEN #{duration} ELSE 0 END) AS week_seconds,
        SUM(CASE WHEN #{table_alias}.ended_at >= #{month_cutoff} THEN #{duration} ELSE 0 END) AS month_seconds,
        SUM(#{duration}) AS all_seconds
      SQL
    end

    def duration_expression(table_alias)
      PrintTimeAccounting.duration_sql(table_alias)
    end

    def countable_jobs_clause(table_alias)
      <<~SQL.squish
        #{table_alias}.status IN ('finished', 'cancelled')
        AND #{table_alias}.ended_at IS NOT NULL
      SQL
    end

    def printer_sql
      <<~SQL.squish
        SELECT printers.id::text AS key,
               printers.name AS label,
               #{period_sums('jobs')}
        FROM jobs
        INNER JOIN printers ON printers.id = jobs.printer_id
        WHERE #{countable_jobs_clause('jobs')}
        GROUP BY printers.id, printers.name
      SQL
    end

    def user_sql
      <<~SQL.squish
        SELECT users.id::text AS key,
               COALESCE(NULLIF(users.username, ''), users.email) AS label,
               #{period_sums('jobs')}
        FROM jobs
        INNER JOIN users ON users.id = jobs.owner_id
        WHERE #{countable_jobs_clause('jobs')}
        GROUP BY users.id, users.username, users.email
      SQL
    end

    def filament_sql
      <<~SQL.squish
        SELECT material AS key,
               material AS label,
               #{filament_period_sums}
        FROM (#{filament_shares_sql}) AS filament_shares
        GROUP BY material
      SQL
    end

    def filament_period_sums
      week_cutoff = connection.quote(WEEK_WINDOW.ago)
      month_cutoff = connection.quote(MONTH_WINDOW.ago)

      <<~SQL.squish
        SUM(CASE WHEN ended_at >= #{week_cutoff} THEN share_seconds ELSE 0 END)::bigint AS week_seconds,
        SUM(CASE WHEN ended_at >= #{month_cutoff} THEN share_seconds ELSE 0 END)::bigint AS month_seconds,
        SUM(share_seconds)::bigint AS all_seconds
      SQL
    end

    def filament_shares_sql
      [filament_tool_shares_sql, filament_unknown_shares_sql].join(' UNION ALL ')
    end

    def filament_tool_shares_sql
      duration = duration_expression('jobs')

      <<~SQL.squish
        SELECT jobs.ended_at,
               COALESCE(NULLIF(tools.material, ''), 'Unknown') AS material,
               (#{duration}::numeric / tool_counts.tool_count) AS share_seconds
        FROM jobs
        INNER JOIN tools ON tools.job_id = jobs.id
        INNER JOIN (
          SELECT job_id, COUNT(*) AS tool_count
          FROM tools
          GROUP BY job_id
        ) AS tool_counts ON tool_counts.job_id = jobs.id
        WHERE #{countable_jobs_clause('jobs')}
      SQL
    end

    def filament_unknown_shares_sql
      duration = duration_expression('jobs')

      <<~SQL.squish
        SELECT jobs.ended_at,
               'Unknown' AS material,
               #{duration}::numeric AS share_seconds
        FROM jobs
        LEFT JOIN tools ON tools.job_id = jobs.id
        WHERE #{countable_jobs_clause('jobs')}
          AND tools.id IS NULL
      SQL
    end

    def connection
      ActiveRecord::Base.connection
    end
  end
end
