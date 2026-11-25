# Helpers for lists of training topic names (settings, printers, users). Topic names are
# compared case-insensitively, the way Authentik's trained_on claim is matched.
module TrainingTopics
  module_function

  # Accepts an array or a string with one topic per line or comma-separated. Strips, drops
  # blanks, and removes case-insensitive duplicates, keeping the first spelling.
  def normalize(value)
    entries = value.is_a?(Array) ? value : value.to_s.split(/[\n,]/)
    entries.filter_map { |entry| entry.to_s.strip.presence }.uniq(&:downcase)
  end

  # Topic names from Authentik's trained_on claim: an array of names or of {name:}/{title:}
  # hashes, a comma-separated string, or a single value.
  def from_claim(value)
    entries = case value
              when Array then value
              when String then value.split(',')
              else [value]
              end
    normalize(entries.map { |entry| claim_entry_name(entry) })
  end

  def claim_entry_name(entry)
    return entry.to_s unless entry.is_a?(Hash)

    %w[name title].each do |key|
      name = (entry[key] || entry[key.to_sym]).to_s.strip
      return name if name.present?
    end
    ''
  end

  def include?(topics, topic)
    topics.any? { |entry| entry.casecmp?(topic.to_s) }
  end

  # Whether +have+ covers every topic in +required+.
  def cover?(have, required)
    required.all? { |topic| include?(have, topic) }
  end
end
