module Prometheus
  # Accumulates metric families and renders them in the Prometheus text exposition format.
  class Exposition
    CONTENT_TYPE = 'text/plain; version=0.0.4; charset=utf-8'.freeze

    def initialize
      @lines = []
    end

    def gauge(name, help, samples)
      family(name, help, 'gauge', samples)
    end

    def counter(name, help, samples)
      family(name, help, 'counter', samples)
    end

    # Cumulative "less than or equal" counts as a gauge. These are recomputed from the database each
    # scrape and can fall when jobs are deleted, so they must not be typed as a Prometheus histogram.
    def cumulative_gauge(name, help, buckets:, values:)
      samples = buckets.map { |bound| [{ le: bound }, values.count { |v| v <= bound }] }
      samples << [{ le: '+Inf' }, values.size]
      gauge(name, help, samples)
    end

    def to_s
      "#{@lines.join("\n")}\n"
    end

    def self.escape_label(value)
      value.to_s.gsub('\\') { '\\\\' }.gsub("\n", '\n').gsub('"') { '\"' }
    end

    private

    # samples: Array of [labels_hash, value] pairs, or a bare number for an unlabelled metric.
    def family(name, help, type, samples)
      header(name, help, type)
      samples = [[{}, samples]] unless samples.is_a?(Array)
      samples.each { |labels, value| @lines << sample(name, labels, value) }
    end

    def header(name, help, type)
      @lines << "# HELP #{name} #{help}"
      @lines << "# TYPE #{name} #{type}"
    end

    def sample(name, labels, value)
      label_text = labels.map { |k, v| "#{k}=\"#{self.class.escape_label(v)}\"" }.join(',')
      label_text = "{#{label_text}}" if label_text.present?
      "#{name}#{label_text} #{format_value(value)}"
    end

    def format_value(value)
      return 'NaN' if value.nil?
      return value.to_f.to_s if value.is_a?(BigDecimal) || value.is_a?(Float)

      value.to_s
    end
  end
end
