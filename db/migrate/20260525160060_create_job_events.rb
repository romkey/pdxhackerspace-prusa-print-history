class CreateJobEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :job_events do |t|
      t.references :job, null: false, foreign_key: true

      t.string   :event_type, null: false
      t.string   :from_status
      t.string   :to_status
      t.text     :message
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :job_events, %i[job_id occurred_at]
  end
end
