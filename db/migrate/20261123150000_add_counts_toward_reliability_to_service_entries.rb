class AddCountsTowardReliabilityToServiceEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :service_entries, :counts_toward_reliability, :boolean, null: false, default: true
  end
end
