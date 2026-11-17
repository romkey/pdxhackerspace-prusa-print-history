module Prometheus
  # Sidekiq queue and process stats, read from Redis. Emits sidekiq_up 0 when Redis can't be read.
  class SidekiqMetrics
    def initialize(exposition)
      @out = exposition
    end

    def collect
      require 'sidekiq/api'
      stats = Sidekiq::Stats.new
      @out.gauge('prusa_history_sidekiq_processes', 'Running Sidekiq processes.', Sidekiq::ProcessSet.new.size)
      sidekiq_gauges(stats)
      @out.gauge('prusa_history_sidekiq_queue_latency_seconds', 'Oldest job age, by queue.',
                 Sidekiq::Queue.all.map { |q| [{ queue: q.name }, q.latency] })
    rescue StandardError => e
      Rails.logger.warn("metrics: Sidekiq stats unavailable: #{e.class}: #{e.message}")
      @out.gauge('prusa_history_sidekiq_up', '1 if Sidekiq stats could be read from Redis.', 0)
    end

    def sidekiq_gauges(stats)
      @out.gauge('prusa_history_sidekiq_busy', 'Sidekiq threads currently working.', stats.workers_size)
      @out.gauge('prusa_history_sidekiq_enqueued', 'Jobs waiting in queues.', stats.enqueued)
      @out.gauge('prusa_history_sidekiq_retries', 'Jobs scheduled for retry.', stats.retry_size)
      @out.gauge('prusa_history_sidekiq_dead', 'Jobs in the dead set.', stats.dead_size)
      @out.counter('prusa_history_sidekiq_processed_total', 'Jobs processed.', stats.processed)
      @out.counter('prusa_history_sidekiq_failed_total', 'Jobs failed.', stats.failed)
    end
  end
end
