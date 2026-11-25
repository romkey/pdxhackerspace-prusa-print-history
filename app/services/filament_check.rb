# Whether a print's filament is one its printer may run (FilamentType#allowed_on?). Reads the
# materials recorded on the job's tools; a material that matches no known filament type
# can't be judged and is let through.
class FilamentCheck
  def self.problem(job, types: FilamentType.ordered.to_a)
    new(job, types:).problem
  end

  def initialize(job, types:)
    @job = job
    @types = types
  end

  # A sentence naming each disallowed filament and what the printer lacks, or nil when the
  # print is fine. e.g. "ABS needs ventilation."
  def problem
    blocked = disallowed_types
    return nil if blocked.empty?

    blocked.map { |type| "#{type.name} needs #{type.missing_on(printer).to_sentence}" }.join('; ').concat('.')
  end

  def disallowed_types
    matched_types.reject { |type| type.allowed_on?(printer) }
  end

  private

  def printer
    @job.printer
  end

  def matched_types
    materials.filter_map { |material| FilamentType.match(material, @types) }.uniq
  end

  def materials
    @job.tools.reload.filter_map { |tool| tool.material.presence }.uniq
  end
end
