class AddClearFieldsToJobs < ActiveRecord::Migration[8.1]
  def change
    change_table :jobs, bulk: true do |t|
      t.datetime :cleared_at
      t.references :cleared_by, foreign_key: { to_table: :users }
      t.string :clear_outcome
      t.string :clear_failure_reason
      t.text :clear_failure_detail
      t.datetime :finished_notified_at
    end
  end
end
