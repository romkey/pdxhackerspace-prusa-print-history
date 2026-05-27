class AddProgressToJobs < ActiveRecord::Migration[8.1]
  def change
    change_table :jobs, bulk: true do |t|
      t.decimal :progress_percent, precision: 5, scale: 2
      t.datetime :estimated_finish_at
      t.integer :time_printing_seconds
    end
  end
end
