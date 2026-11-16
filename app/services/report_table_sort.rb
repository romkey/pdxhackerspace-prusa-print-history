class ReportTableSort
  PRINT_TIME = {
    'name' => :label,
    'week' => :week_seconds,
    'month' => :month_seconds,
    'all' => :all_seconds
  }.freeze

  ATTENTION = {
    'name' => :label,
    'week' => :week_count,
    'month' => :month_count,
    'all' => :all_count
  }.freeze

  RELIABILITY = {
    'name' => :label,
    'score' => :sort_score,
    'attentions' => :attentions,
    'problems' => :problems,
    'repairs' => :repairs,
    'days' => :days_out,
    'jobs' => :jobs
  }.freeze

  class << self
    def call(rows, columns:, sort:, direction:)
      column, dir = normalize(sort, direction, columns)
      accessor = columns.fetch(column)
      rows.sort { |left, right| compare(left, right, accessor, dir) }
    end

    def normalize(sort, direction, columns)
      column = columns.key?(sort.to_s) ? sort.to_s : 'name'
      [column, direction_for(column, direction)]
    end

    private

    def direction_for(column, direction)
      return direction.to_s if %w[asc desc].include?(direction.to_s)

      column == 'name' ? 'asc' : 'desc'
    end

    def compare(left, right, accessor, direction)
      result = directed(primary_value(left, accessor) <=> primary_value(right, accessor), direction)
      result.nonzero? || left.label.to_s.casecmp(right.label.to_s).nonzero? || left.key.to_s <=> right.key.to_s
    end

    def primary_value(row, accessor)
      value = row.public_send(accessor)
      accessor == :label ? value.to_s.downcase : value.to_i
    end

    def directed(comparison, direction)
      direction == 'desc' ? -comparison : comparison
    end
  end
end
