class PrintTimeAccounting
  def self.duration_sql(table = 'jobs')
    <<~SQL.squish
      COALESCE(
        #{table}.total_duration_seconds,
        CASE
          WHEN #{table}.started_at IS NOT NULL AND #{table}.ended_at IS NOT NULL
          THEN EXTRACT(EPOCH FROM (#{table}.ended_at - #{table}.started_at))::integer
          ELSE 0
        END
      )
    SQL
  end

  def self.countable_jobs
    Job.terminal.where.not(owner_id: nil).where.not(ended_at: nil)
  end

  def self.sync_user_total!(user_or_id)
    user = user_or_id.is_a?(User) ? user_or_id : User.find_by(id: user_or_id)
    return unless user

    total = countable_jobs.where(owner_id: user.id).sum(Arel.sql(duration_sql))
    user.update!(total_print_seconds: total.to_i)
  end

  def self.sync_users_for_job!(job, previous_owner_id: nil)
    user_ids = [job.owner_id, previous_owner_id].compact.uniq
    User.where(id: user_ids).find_each { |user| sync_user_total!(user) }
  end
end
