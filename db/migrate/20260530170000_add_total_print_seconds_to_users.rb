class AddTotalPrintSecondsToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :total_print_seconds, :integer, null: false, default: 0

    say_with_time 'Backfilling users.total_print_seconds from terminal owned jobs' do
      execute <<~SQL.squish
        UPDATE users
        SET total_print_seconds = totals.seconds
        FROM (
          SELECT owner_id,
                 SUM(COALESCE(
                   jobs.total_duration_seconds,
                   CASE
                     WHEN jobs.started_at IS NOT NULL AND jobs.ended_at IS NOT NULL
                     THEN EXTRACT(EPOCH FROM (jobs.ended_at - jobs.started_at))::integer
                     ELSE 0
                   END
                 )) AS seconds
          FROM jobs
          WHERE status IN ('finished', 'cancelled')
            AND owner_id IS NOT NULL
            AND ended_at IS NOT NULL
          GROUP BY owner_id
        ) AS totals
        WHERE users.id = totals.owner_id
      SQL
    end
  end

  def down
    remove_column :users, :total_print_seconds
  end
end
