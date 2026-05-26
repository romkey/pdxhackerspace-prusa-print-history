class CreateJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :jobs do |t|
      t.references :printer, null: false, foreign_key: true
      t.references :owner,   foreign_key: { to_table: :users }

      t.string   :filename, null: false
      t.string   :status,   null: false, default: 'pending'
      t.string   :prusalink_job_id
      t.datetime :started_at
      t.datetime :ended_at
      t.integer  :total_duration_seconds
      t.decimal  :total_filament_grams, precision: 10, scale: 2

      t.timestamps
    end

    add_index :jobs, %i[printer_id prusalink_job_id],
              unique: true,
              where: 'prusalink_job_id IS NOT NULL',
              name: 'idx_jobs_on_printer_and_prusalink_job_id'
    add_index :jobs, :status
    add_index :jobs, :started_at
  end
end
