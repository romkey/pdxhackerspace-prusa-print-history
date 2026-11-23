class AddAutomaticToServiceEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :service_entries, :automatic, :boolean, default: false, null: false
  end
end
