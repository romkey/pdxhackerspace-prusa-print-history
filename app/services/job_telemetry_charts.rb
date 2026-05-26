class JobTelemetryCharts
  SERIES = {
    'Bed' => :bed_temp,
    'Enclosure' => :enclosure_temp,
    'Ambient' => :ambient_temp
  }.freeze

  def self.series_for(readings)
    return {} if readings.blank?

    series = SERIES.filter_map do |label, attribute|
      points = points_for(readings, attribute)
      [label, points] if points.any?
    end.to_h

    tool_indices(readings).each do |index|
      points = tool_points_for(readings, index)
      series["T#{index}"] = points if points.any?
    end

    series
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
