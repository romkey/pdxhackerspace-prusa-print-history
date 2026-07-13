class PrintTimeReport
  Row = Data.define(:key, :label, :week_seconds, :month_seconds, :all_seconds)

  WEEK_WINDOW = 7.days
  MONTH_WINDOW = 30.days

  CHART_PERIODS = [
    ['Last 7 days', :week_seconds],
    ['Last 30 days', :month_seconds],
    ['All time', :all_seconds]
  ].freeze

  class << self
    def by_printer
      merge_rows(Printer.ordered, rows_from_sql(printer_sql))
    end

    def by_user
      rows = rows_from_sql(user_report_sql)
      unclaimed = rows.find { |row| row.key == 'unclaimed' } || empty_row('unclaimed', 'Unclaimed')
      claimed_rows = label_user_rows(rows.reject { |row| row.key == 'unclaimed' })
      merge_rows(User.in_display_name_order, claimed_rows) + [unclaimed]
    end

    def by_filament
      rows_from_sql(filament_sql)
    end

    def chart_series(rows, limit: 10)
      top_rows = chartable_rows(rows, limit)
      return [] if top_rows.empty?

      CHART_PERIODS.map do |label, accessor|
        { name: label, data: top_rows.map { |row| [row.label, hours(row.public_send(accessor))] } }
      end
    end

    private

    def chartable_rows(rows, limit)
      rows.sort_by { |row| [-row.all_seconds, row.label.downcase] }
          .first(limit)
          .reject { |row| row.week_seconds.zero? && row.month_seconds.zero? && row.all_seconds.zero? }
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
      week_cutoff = ActiveRecord::Base.connection.quote(WEEK_WINDOW.ago)
      month_cutoff = ActiveRecord::Base.connection.quote(MONTH_WINDOW.ago)
      duration = PrintTimeAccounting.duration_sql(table_alias)

      <<~SQL.squish
        SUM(CASE WHEN #{table_alias}.ended_at >= #{week_cutoff} THEN #{duration} ELSE 0 END) AS week_seconds,
        SUM(CASE WHEN #{table_alias}.ended_at >= #{month_cutoff} THEN #{duration} ELSE 0 END) AS month_seconds,
        SUM(#{duration}) AS all_seconds
      SQL
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

    def label_user_rows(rows)
      users_by_id = User.where(id: rows.map(&:key)).index_by { |user| user.id.to_s }

      rows.map do |row|
        user = users_by_id[row.key]
        Row.new(
          key: row.key,
          label: user ? user.display_name : row.label,
          week_seconds: row.week_seconds,
          month_seconds: row.month_seconds,
          all_seconds: row.all_seconds
        )
      end
    end

    def user_report_sql
      <<~SQL.squish
        SELECT users.id::text AS key,
               users.id::text AS label,
               #{period_sums('jobs')}
        FROM jobs
        INNER JOIN users ON users.id = jobs.owner_id
        WHERE #{countable_jobs_clause('jobs')}
        GROUP BY users.id

        UNION ALL

        SELECT 'unclaimed' AS key,
               'Unclaimed' AS label,
               #{period_sums('jobs')}
        FROM jobs
        WHERE #{countable_jobs_clause('jobs')}
          AND jobs.owner_id IS NULL
      SQL
    end

    def filament_sql
      week_cutoff = ActiveRecord::Base.connection.quote(WEEK_WINDOW.ago)
      month_cutoff = ActiveRecord::Base.connection.quote(MONTH_WINDOW.ago)

      <<~SQL.squish
        SELECT material AS key,
               material AS label,
               SUM(CASE WHEN ended_at >= #{week_cutoff} THEN share_seconds ELSE 0 END)::bigint AS week_seconds,
               SUM(CASE WHEN ended_at >= #{month_cutoff} THEN share_seconds ELSE 0 END)::bigint AS month_seconds,
               SUM(share_seconds)::bigint AS all_seconds
        FROM (#{filament_shares_sql}) AS filament_shares
        GROUP BY material
      SQL
    end

    def filament_shares_sql
      [filament_tool_shares_sql, filament_unknown_shares_sql].join(' UNION ALL ')
    end

    def filament_tool_shares_sql
      duration = PrintTimeAccounting.duration_sql('jobs')

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
      duration = PrintTimeAccounting.duration_sql('jobs')

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
  end
end
