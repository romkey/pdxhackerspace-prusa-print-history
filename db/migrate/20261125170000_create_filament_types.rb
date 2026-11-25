class CreateFilamentTypes < ActiveRecord::Migration[8.1]
  class MigrationFilamentType < ActiveRecord::Base
    self.table_name = 'filament_types'
  end

  def change
    create_table :filament_types do |t|
      t.string :name, null: false
      t.string :aliases
      t.integer :nozzle_min_c, null: false
      t.integer :nozzle_max_c, null: false
      t.integer :bed_min_c, null: false
      t.integer :bed_max_c, null: false
      t.boolean :requires_hardened_nozzle, default: false, null: false
      t.boolean :requires_ventilation, default: false, null: false
      t.timestamps
    end
    add_index :filament_types, 'lower(name)', unique: true, name: 'index_filament_types_on_lower_name'

    add_column :printers, :hardened_nozzle, :boolean, default: false, null: false
    add_column :printers, :ventilation, :boolean, default: false, null: false

    # Why a print was paused for its filament (shown on the dashboard), and when.
    add_column :jobs, :filament_hold_at, :datetime
    add_column :jobs, :filament_hold_reason, :string
    add_index :jobs, :filament_hold_at, where: 'filament_hold_at IS NOT NULL'

    reversible { |dir| dir.up { seed_filament_types } }
  end

  private

  def seed_filament_types
    MigrationFilamentType.reset_column_information
    now = Time.current
    rows = FilamentType::DEFAULTS.map do |attrs|
      {
        name: attrs[:name], aliases: attrs[:aliases],
        nozzle_min_c: attrs[:nozzle].min, nozzle_max_c: attrs[:nozzle].max,
        bed_min_c: attrs[:bed].min, bed_max_c: attrs[:bed].max,
        requires_hardened_nozzle: attrs.fetch(:hardened, false),
        requires_ventilation: attrs.fetch(:ventilation, false),
        created_at: now, updated_at: now
      }
    end
    MigrationFilamentType.insert_all(rows)
  end
end
