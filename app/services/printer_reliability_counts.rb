# Aggregate counts for PrinterReliability. Attentions count only while the
# printer was in service. A period that started before the window and has
# not ended still excludes attentions inside the window. Problems and repairs
# marked as not counting toward reliability (e.g. the printer was unplugged,
# not faulty) are left out.
class PrinterReliabilityCounts
  def initialize(window_start)
    @window_start = window_start
  end

  def attentions = grouped(attention_sql)
  def problems = entry_counts('problem')
  def repairs = entry_counts('repair')
  def jobs = grouped(job_sql)

  private

  def entry_counts(kind)
    grouped(<<~SQL.squish)
      SELECT printer_id, COUNT(*) AS count
      FROM service_entries
      WHERE kind = #{quote(kind)} AND NOT automatic AND occurred_at >= #{quote(@window_start)}
        AND counts_toward_reliability
      GROUP BY printer_id
    SQL
  end

  def grouped(sql)
    ActiveRecord::Base.connection.select_all(sql).to_h do |row|
      [row['printer_id'].to_i, row['count'].to_i]
    end
  end

  def attention_sql
    <<~SQL.squish
      SELECT jobs.printer_id AS printer_id, COUNT(*) AS count
      FROM job_events
      INNER JOIN jobs ON jobs.id = job_events.job_id
      WHERE job_events.event_type = 'attention'
        AND job_events.occurred_at >= #{quote(@window_start)}
        AND NOT #{out_of_service_exists_sql}
      GROUP BY jobs.printer_id
    SQL
  end

  def out_of_service_exists_sql
    <<~SQL.squish
      EXISTS (
        SELECT 1 FROM service_entries outs
        WHERE outs.printer_id = jobs.printer_id
          AND outs.kind = 'out_of_service'
          AND outs.occurred_at <= job_events.occurred_at
          AND NOT EXISTS (
            SELECT 1 FROM service_entries backs
            WHERE backs.printer_id = outs.printer_id
              AND backs.kind = 'back_in_service'
              AND backs.occurred_at > outs.occurred_at
              AND backs.occurred_at <= job_events.occurred_at
          )
      )
    SQL
  end

  def job_sql
    <<~SQL.squish
      SELECT printer_id, COUNT(*) AS count
      FROM jobs
      WHERE COALESCE(started_at, created_at) >= #{quote(@window_start)}
      GROUP BY printer_id
    SQL
  end

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end
end
