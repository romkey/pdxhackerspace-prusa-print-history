# A kind of filament (PLA, PETG, ...) with the temperatures it prints at and what a printer
# needs to run it. A printer may print a filament type unless the type needs a hardened
# nozzle or ventilation the printer doesn't have. Admins edit the list under Settings.
class FilamentType < ApplicationRecord
  TEMPERATURE_RANGE = (0..500)
  # Words that mark a filament as fiber-filled, and so abrasive.
  FIBER_MARKER = /(?<![[:alnum:]])(CF|GF|CARBON|GLASS)(?![[:alnum:]])/

  # Seeded on a new install and by the migration that added the table. Temperatures are
  # typical manufacturer ranges in °C; admins can adjust them.
  DEFAULTS = [
    { name: 'PLA', nozzle: 190..230, bed: 45..65 },
    { name: 'PETG', nozzle: 220..260, bed: 65..90, aliases: 'PET-G' },
    { name: 'ABS', nozzle: 240..280, bed: 90..110, ventilation: true },
    { name: 'ASA', nozzle: 240..280, bed: 90..110, ventilation: true },
    { name: 'TPU', nozzle: 200..240, bed: 30..60, aliases: 'FLEX' },
    { name: 'PC', nozzle: 260..300, bed: 100..120, ventilation: true },
    { name: 'PA', nozzle: 260..300, bed: 70..110, ventilation: true, aliases: 'Nylon, PA6, PA12' },
    { name: 'PA-CF', nozzle: 260..300, bed: 80..110, hardened: true, ventilation: true,
      aliases: 'PA6-CF, PA12-CF, PAHT-CF, PA11-CF' },
    { name: 'PLA-CF', nozzle: 210..240, bed: 45..65, hardened: true },
    { name: 'PETG-CF', nozzle: 230..270, bed: 65..90, hardened: true, aliases: 'PET-CF' },
    { name: 'PVA', nozzle: 190..220, bed: 45..60 },
    { name: 'HIPS', nozzle: 220..250, bed: 90..110, ventilation: true }
  ].freeze

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :nozzle_min_c, :nozzle_max_c, :bed_min_c, :bed_max_c,
            presence: true, numericality: { only_integer: true, in: TEMPERATURE_RANGE }
  validate :ranges_ascend

  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :aliases, with: ->(value) { value.to_s.split(',').filter_map { |a| a.strip.presence }.join(', ') }

  scope :ordered, -> { order(:name) }

  # Adds any default type that isn't there yet (by name). Existing types are left alone.
  def self.seed_defaults!
    existing = pluck(:name).map(&:downcase)
    DEFAULTS.each do |attrs|
      next if existing.include?(attrs[:name].downcase)

      create!(attributes_from_default(attrs))
    end
  end

  def self.attributes_from_default(attrs)
    {
      name: attrs[:name], aliases: attrs[:aliases],
      nozzle_min_c: attrs[:nozzle].min, nozzle_max_c: attrs[:nozzle].max,
      bed_min_c: attrs[:bed].min, bed_max_c: attrs[:bed].max,
      requires_hardened_nozzle: attrs.fetch(:hardened, false),
      requires_ventilation: attrs.fetch(:ventilation, false)
    }
  end
  private_class_method :attributes_from_default

  # The type a printer or slicer material string refers to, or nil. Matches a name or alias
  # exactly (ignoring case), then the longest name or alias the material starts with,
  # followed by a space ("PLA Basic" is PLA, "PETG HF" is PETG). A material whose extra words
  # mark it fiber-filled ("Nylon CF") never falls back to its unfilled base type, which would
  # skip the hardened-nozzle check; it must match a CF/GF type by name or alias instead.
  def self.match(material, types = ordered.to_a)
    value = material.to_s.strip.upcase
    return nil if value.empty?

    candidates = types.flat_map { |type| type.match_names.map { |name| [name.upcase, type] } }
    exact_match(candidates, value) || leading_word_match(candidates, value)
  end

  def self.exact_match(candidates, value)
    candidates.find { |name, _| name == value }&.last
  end

  def self.leading_word_match(candidates, value)
    candidates.select { |name, _| leading_word?(value, name) }
              .max_by { |name, _| name.length }&.last
  end

  def self.leading_word?(value, name)
    return false unless value.start_with?("#{name} ")

    !value.delete_prefix(name).match?(FIBER_MARKER)
  end
  private_class_method :exact_match, :leading_word_match, :leading_word?

  def match_names
    [name, *aliases.to_s.split(',').map(&:strip)].compact_blank
  end

  def allowed_on?(printer)
    missing_on(printer).empty?
  end

  # What the printer lacks for this type, e.g. ["a hardened nozzle", "ventilation"].
  def missing_on(printer)
    missing = []
    missing << 'a hardened nozzle' if requires_hardened_nozzle? && !printer.hardened_nozzle?
    missing << 'ventilation' if requires_ventilation? && !printer.ventilation?
    missing
  end

  def nozzle_range_label
    "#{nozzle_min_c}–#{nozzle_max_c} °C"
  end

  def bed_range_label
    "#{bed_min_c}–#{bed_max_c} °C"
  end

  private

  def ranges_ascend
    check_range(:nozzle_min_c, :nozzle_max_c)
    check_range(:bed_min_c, :bed_max_c)
  end

  def check_range(min_attr, max_attr)
    low = self[min_attr]
    high = self[max_attr]
    errors.add(max_attr, 'must be at least the minimum') if low && high && high < low
  end
end
