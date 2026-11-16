class PrinterReliability
  WINDOW = 90.days
  MIN_JOBS = 5
  ATTENTION_PENALTY = 3
  PROBLEM_PENALTY = 5
  REPAIR_PENALTY = 8

  Score = Data.define(:printer, :score, :attentions, :problems, :repairs, :jobs, :days_out) do
    def label = printer.name
    def key = printer.id.to_s

    def rated?
      jobs >= PrinterReliability::MIN_JOBS
    end

    def display_score
      rated? ? score : nil
    end
  end

  def self.all
    new.scores
  end

  def self.for_printer(printer)
    all.find { |row| row.printer.id == printer.id } || blank_score(printer)
  end

  def self.blank_score(printer)
    Score.new(printer:, score: 100, attentions: 0, problems: 0, repairs: 0, jobs: 0, days_out: 0)
  end

  def scores
    Printer.ordered.map { |printer| score_for(printer) }
  end

  private

  def score_for(printer)
    attentions, problems, repairs, jobs = counts_for(printer)
    Score.new(
      printer:, attentions:, problems:, repairs:, jobs:,
      score: raw_score(attentions, problems, repairs),
      days_out: days_out_for(printer)
    )
  end

  def counts_for(printer)
    [
      count_for(attention_counts, printer),
      count_for(problem_counts, printer),
      count_for(repair_counts, printer),
      count_for(job_counts, printer)
    ]
  end

  def raw_score(attentions, problems, repairs)
    penalty = (attentions * ATTENTION_PENALTY) + (problems * PROBLEM_PENALTY) + (repairs * REPAIR_PENALTY)
    (100 - penalty).clamp(0, 100)
  end

  def count_for(counts, printer)
    counts.fetch(printer.id, 0)
  end

  def attention_counts
    @attention_counts ||= totals.attentions
  end

  def problem_counts
    @problem_counts ||= totals.problems
  end

  def repair_counts
    @repair_counts ||= totals.repairs
  end

  def job_counts
    @job_counts ||= totals.jobs
  end

  def totals
    @totals ||= PrinterReliabilityCounts.new(window_start)
  end

  def days_out_for(printer)
    ServiceOutagePeriods.days_within(outage_periods.fetch(printer.id, []), window_start, Time.current)
  end

  def outage_periods
    @outage_periods ||= ServiceOutagePeriods.by_printer(status_entries)
  end

  def status_entries
    ServiceEntry.where(kind: %w[out_of_service back_in_service]).select(:id, :printer_id, :kind, :occurred_at)
  end

  def window_start
    @window_start ||= WINDOW.ago
  end
end
