# Turns out-of-service and back-in-service log entries into time ranges.
class ServiceOutagePeriods
  class << self
    def by_printer(entries)
      entries.group_by(&:printer_id).transform_values { |rows| new(rows).periods }
    end

    def days_within(periods, window_start, window_end)
      seconds = periods.sum { |period| overlap_seconds(period, window_start, window_end) }
      (seconds / 1.day).round
    end

    private

    def overlap_seconds(period, window_start, window_end)
      start_at = [period.begin, window_start].max
      finish_at = [period.end, window_end].min
      return 0 if finish_at <= start_at

      finish_at - start_at
    end
  end

  def initialize(entries)
    @entries = entries.sort_by(&:occurred_at)
  end

  def periods
    open_at = nil
    closed = []
    @entries.each { |entry| open_at, closed = apply(entry, open_at, closed) }
    closed << (open_at..Time.current) if open_at
    closed
  end

  private

  def apply(entry, open_at, closed)
    case entry.kind
    when 'out_of_service'
      [open_at || entry.occurred_at, closed]
    when 'back_in_service'
      close_period(open_at, closed, entry.occurred_at)
    else
      [open_at, closed]
    end
  end

  def close_period(open_at, closed, finished_at)
    return [open_at, closed] unless open_at

    [nil, closed + [(open_at..finished_at)]]
  end
end
