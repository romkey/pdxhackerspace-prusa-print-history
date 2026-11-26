# Per-printer switches for claim and filament enforcement. Each only matters while its global
# setting (Setting.enforce_claims? / enforce_filament_types?) is on. Default on, so turning a
# global setting on covers every printer until an admin opts one out.
class AddEnforcementTogglesToPrinters < ActiveRecord::Migration[8.1]
  def change
    add_column :printers, :enforce_claims, :boolean, default: true, null: false
    add_column :printers, :enforce_filament_types, :boolean, default: true, null: false
  end
end
