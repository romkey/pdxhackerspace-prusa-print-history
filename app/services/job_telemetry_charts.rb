class JobTelemetryCharts
  SERIES = {
    'Bed' => { attribute: :bed_temp, color: '#e07a5f' },
    'Enclosure' => { attribute: :enclosure_temp, color: '#81b29a' },
    'Ambient' => { attribute: :ambient_temp, color: '#457b9d' }
  }.freeze

  TOOL_COLORS = %w[#f2cc8f #d4a373 #3d405b #bc6c25].freeze

  def self.series_for(readings, job: nil)
    filtered = filter_readings(readings, job)
    return [] if filtered.blank?

    series = SERIES.filter_map do |label, config|
      points = points_for(filtered, config[:attribute])
      next if points.empty?

      { name: label, data: points, color: config[:color] }
    end

    tool_indices(filtered).each_with_index do |index, color_index|
      points = tool_points_for(filtered, index)
      next if points.empty?

      series << {
        name: "T#{index}",
        data: points,
        color: TOOL_COLORS[color_index % TOOL_COLORS.size]
      }
    end

    series
  end

  def self.chart_options(job)
    return {} if job&.started_at.blank?

    {
      xmin: job.started_at,
      xmax: job.ended_at || Time.current
    }
  end

  def self.filter_readings(readings, job)
    return readings if job.blank? || job.started_at.blank?

    window_end = job.ended_at || Time.current
    readings.select { |reading| reading.recorded_at.between?(job.started_at, window_end) }
  end

  def self.points_for(readings, attribute)
    readings.filter_map do |reading|
      value = reading.public_send(attribute)
      next if value.blank?

      [reading.recorded_at, value.to_f]
    end
  end

  def self.tool_points_for(readings, index)
    readings.filter_map do |reading|
      value = reading.tool_temp(index)
      next if value.blank?

      [reading.recorded_at, value.to_f]
    end
  end

  def self.tool_indices(readings)
    readings.flat_map { |reading| reading.tool_temps.keys }.uniq.sort_by(&:to_i)
  end
end
