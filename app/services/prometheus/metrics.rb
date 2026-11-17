module Prometheus
  # Builds the /metrics payload. Everything is computed with grouped queries so a scrape stays cheap
  # no matter how many jobs exist. Printer names are the only per-printer identifier exposed.
  class Metrics
    DURATION_BUCKETS = [300, 900, 1800, 3600, 7200, 14_400, 28_800, 57_600, 86_400, 172_800].freeze

    def self.render
      new.render
    end

    def initialize(exposition: Exposition.new)
      @out = exposition
    end

    def render
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      build_info
      user_metrics
      printer_metrics
      environment_metrics
      job_metrics
      service_metrics
      infrastructure_metrics
      @out.gauge('prusa_history_scrape_duration_seconds', 'Time spent building this response.',
                 Process.clock_gettime(Process::CLOCK_MONOTONIC) - started)
      @out.to_s
    end

    private

    def build_info
      version = Rails.root.join('VERSION').read.strip
      @out.gauge('prusa_history_build_info', 'Application version.', [[{ version: }, 1]])
    rescue Errno::ENOENT
      @out.gauge('prusa_history_build_info', 'Application version.', [[{ version: 'unknown' }, 1]])
    end

    def user_metrics
      @out.gauge('prusa_history_users', 'Number of users.', User.count)
      @out.gauge('prusa_history_admin_users', 'Number of admin users.', User.where(admin: true).count)
      @out.gauge('prusa_history_users_active_30d', 'Users who signed in during the last 30 days.',
                 User.where(last_login_at: 30.days.ago..).count)
      @out.gauge('prusa_history_users_trained_on_prusa', 'Users marked as trained on the Prusa printers.',
                 User.where(trained_on_prusa: true).count)
      @out.gauge('prusa_history_user_print_seconds', 'Print time credited to users, in seconds.',
                 User.sum(:total_print_seconds))
    end

    def printer_metrics
      printers = Printer.ordered.to_a
      @out.gauge('prusa_history_printers', 'Printers by type.', grouped(printers))
      @out.gauge('prusa_history_printers_out_of_service', 'Printers currently marked out of service.',
                 printers.count { |p| p.out_of_service_since.present? })
      per_printer('prusa_history_printer_reachable', '1 if the printer answered its last poll.', printers) do |p|
        p.prusalink_reachable ? 1 : 0
      end
      per_printer('prusa_history_printer_out_of_service', '1 if the printer is out of service.', printers) do |p|
        p.out_of_service_since.present? ? 1 : 0
      end
      printer_states(printers)
      reliability_metrics
    end

    def printer_states(printers)
      counts = printers.group_by(&:operational_state).transform_values(&:size)
      samples = Printer::OPERATIONAL_STATES.map { |s| [{ state: s }, counts.fetch(s, 0)] }
      @out.gauge('prusa_history_printers_by_state', 'Printers by operational state.', samples)
      samples = printers.flat_map do |p|
        Printer::OPERATIONAL_STATES.map { |s| [{ printer: p.name, state: s }, p.operational_state == s ? 1 : 0] }
      end
      @out.gauge('prusa_history_printer_state', '1 for the printer\'s current operational state.', samples)
    end

    def reliability_metrics
      scores = PrinterReliability.all
      @out.gauge('prusa_history_printer_reliability_score',
                 'Reliability score (0-100) over the last 90 days; omitted until a printer has enough jobs.',
                 scores.select(&:rated?).map { |r| [{ printer: r.printer.name }, r.score] })
      @out.gauge('prusa_history_printer_jobs_90d', 'Jobs in the last 90 days.',
                 scores.map { |r| [{ printer: r.printer.name }, r.jobs] })
      @out.gauge('prusa_history_printer_attentions_90d', 'Attention events in the last 90 days.',
                 scores.map { |r| [{ printer: r.printer.name }, r.attentions] })
    end

    def environment_metrics
      printers = Printer.ordered.to_a
      { 'ambient_temperature_celsius' => :ambient_temp, 'enclosure_temperature_celsius' => :enclosure_temp,
        'enclosure_humidity_percent' => :enclosure_humidity }.each do |name, column|
        samples = printers.filter_map { |p| [{ printer: p.name }, p[column]] unless p[column].nil? }
        @out.gauge("prusa_history_printer_#{name}", "Latest #{column.to_s.tr('_', ' ')} reading.", samples)
      end
    end

    def job_metrics
      job_counts
      job_totals
      job_durations
      @out.gauge('prusa_history_job_events', 'Job events recorded, by type.',
                 JobEvent.group(:event_type).count.map { |type, n| [{ event_type: type }, n] })
      @out.gauge('prusa_history_photo_captures', 'Stored photo captures.', PhotoCapture.count)
    end

    def job_counts
      by_status = Job.group(:status).count
      @out.gauge('prusa_history_jobs', 'Jobs by status.',
                 Job::STATUSES.map { |s| [{ status: s }, by_status.fetch(s, 0)] })
      per_printer_status = Job.joins(:printer).group('printers.name', :status).count
      @out.gauge('prusa_history_jobs_by_printer', 'Jobs by printer and status.',
                 per_printer_status.map { |(name, status), n| [{ printer: name, status: }, n] })
      job_outcomes
      @out.gauge('prusa_history_jobs_private', 'Jobs marked private.', Job.where(private: true).count)
      @out.gauge('prusa_history_jobs_unclaimed', 'Jobs with no owner.', Job.where(owner_id: nil).count)
    end

    def job_outcomes
      cleared = Job.where.not(cleared_at: nil).group(:clear_outcome)
      @out.gauge('prusa_history_jobs_cleared', 'Cleared jobs by outcome.',
                 labelled_counts(cleared, :outcome, 'unknown'))
      failed = Job.where(clear_outcome: 'failed').group(:clear_failure_reason)
      @out.gauge('prusa_history_job_failures', 'Failed prints by reason given when clearing.',
                 labelled_counts(failed, :reason, 'unknown'))
    end

    def job_totals
      @out.gauge('prusa_history_print_seconds', 'Time spent printing, in seconds, by printer.',
                 sums(:time_printing_seconds))
      @out.gauge('prusa_history_filament_grams', 'Filament used, in grams, by printer.',
                 sums(:total_filament_grams))
    end

    def job_durations
      values = Job.terminal.where.not(total_duration_seconds: nil).pluck(:total_duration_seconds)
      @out.cumulative_gauge('prusa_history_jobs_within_duration', 'Finished and cancelled jobs lasting at most le sec.',
                            buckets: DURATION_BUCKETS, values:)
      @out.gauge('prusa_history_job_duration_seconds_sum', 'Combined duration of finished and cancelled jobs.',
                 values.sum)
    end

    def service_metrics
      @out.gauge('prusa_history_service_open_problems', 'Open problem reports by printer.',
                 ServiceEntry.open.joins(:printer).group('printers.name').count.map { |n, c| [{ printer: n }, c] })
      @out.gauge('prusa_history_service_entries', 'Service log entries by kind.',
                 ServiceEntry.group(:kind).count.map { |k, c| [{ kind: k }, c] })
    end

    def infrastructure_metrics
      home_assistant_metrics
      @out.gauge('prusa_history_label_printers', 'Label printers by health status.',
                 LabelPrinter.group(:health_status).count.map { |s, c| [{ status: s }, c] })
      SidekiqMetrics.new(@out).collect
    end

    def home_assistant_metrics
      health = Setting.home_assistant_health
      @out.gauge('prusa_history_home_assistant_ok', '1 if the last Home Assistant check succeeded.',
                 health[:status].to_s == 'ok' ? 1 : 0)
      @out.gauge('prusa_history_home_assistant_last_poll_timestamp_seconds',
                 'Unix time of the last Home Assistant poll.', health[:polled_at].to_i)
    end

    def sums(column)
      Job.joins(:printer).group('printers.name').sum(column).map { |n, v| [{ printer: n }, v || 0] }
    end

    def per_printer(name, help, printers)
      @out.gauge(name, help, printers.map { |p| [{ printer: p.name }, yield(p)] })
    end

    def grouped(printers)
      printers.group_by(&:printer_type).map { |type, rows| [{ printer_type: type }, rows.size] }
    end

    def labelled_counts(relation, label, fallback = nil)
      relation.count.map { |key, count| [{ label => key || fallback }, count] }
    end
  end
end
