# Adds the filament types Prusa and Bambu sell that the first list lacked, the names their
# printers report for existing types, and marks TPU as needing ventilation. Types an admin has
# already added (by name) are left alone.
class AddMoreFilamentTypes < ActiveRecord::Migration[8.1]
  class MigrationFilamentType < ActiveRecord::Base
    self.table_name = 'filament_types'
  end

  # name, nozzle range, bed range, hardened nozzle, ventilation, aliases
  NEW_TYPES = [
    ['PETG-ESD', 250..270, 80..90, true, false, nil],
    ['PET-CF', 260..290, 80..100, true, true, nil],
    ['ABS-GF', 240..280, 90..100, true, true, nil],
    ['ASA-Aero', 240..280, 90..100, false, true, 'ASA Aero'],
    ['ASA-CF', 250..280, 90..100, true, true, nil],
    ['PC-CF', 270..300, 100..115, true, true, nil],
    ['PA-GF', 260..300, 90..100, true, true, 'PA6-GF'],
    ['PPA-CF', 280..320, 100..110, true, true, nil],
    ['PPS-CF', 310..340, 100..110, true, true, nil],
    ['PP', 220..250, 55..100, false, false, nil],
    ['PP-GF', 235..255, 90..100, true, false, nil],
    ['PP-CF', 250..280, 85..95, true, false, nil],
    ['PEI', 395..410, 140..150, false, true, 'PEI 1010, ULTEM'],
    ['PVB', 205..225, 65..85, false, false, nil],
    ['BVOH', 210..230, 50..70, false, false, nil]
  ].freeze

  ADDED_ALIASES = {
    'PLA' => ['PLA-AERO', 'PLA-S', 'Support W'],
    'PETG' => ['PET'],
    'ABS' => ['ABS-S'],
    'TPU' => ['TPU-AMS', 'TPU for AMS'],
    'PC' => ['PC FR'],
    'PA' => ['PA-S', 'Support G']
  }.freeze

  # PET-CF is its own type now (it needs ventilation; PETG-CF doesn't).
  REMOVED_ALIASES = { 'PETG-CF' => ['PET-CF'] }.freeze

  def up
    MigrationFilamentType.reset_column_information
    insert_new_types
    ADDED_ALIASES.each { |name, names| change_aliases(name) { |list| list | names } }
    REMOVED_ALIASES.each { |name, names| change_aliases(name) { |list| list - names } }
    named('TPU').update_all(requires_ventilation: true, updated_at: Time.current)
  end

  def down
    named('TPU').update_all(requires_ventilation: false, updated_at: Time.current)
    REMOVED_ALIASES.each { |name, names| change_aliases(name) { |list| list | names } }
    ADDED_ALIASES.each { |name, names| change_aliases(name) { |list| list - names } }
    MigrationFilamentType.where('lower(name) IN (?)', NEW_TYPES.map { |row| row.first.downcase }).delete_all
  end

  private

  def insert_new_types
    existing = MigrationFilamentType.pluck(:name).map(&:downcase)
    now = Time.current
    rows = NEW_TYPES.reject { |row| existing.include?(row.first.downcase) }.map do |name, nozzle, bed, hard, vent, aliases|
      { name: name, aliases: aliases, nozzle_min_c: nozzle.min, nozzle_max_c: nozzle.max,
        bed_min_c: bed.min, bed_max_c: bed.max, requires_hardened_nozzle: hard,
        requires_ventilation: vent, created_at: now, updated_at: now }
    end
    MigrationFilamentType.insert_all(rows) if rows.any?
  end

  def change_aliases(name)
    named(name).find_each do |type|
      list = type.aliases.to_s.split(',').filter_map { |a| a.strip.presence }
      updated = yield(list)
      type.update_columns(aliases: updated.join(', '), updated_at: Time.current) if updated != list
    end
  end

  def named(name)
    MigrationFilamentType.where('lower(name) = ?', name.downcase)
  end
end
