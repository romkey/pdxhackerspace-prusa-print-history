class CreatePhotoCaptures < ActiveRecord::Migration[8.1]
  def change
    create_table :photo_captures do |t|
      t.references :printer, null: false, foreign_key: true
      t.references :job, null: true, foreign_key: true
      t.references :job_event, null: true, foreign_key: true
      t.datetime :captured_at, null: false

      t.timestamps
    end

    add_index :photo_captures, %i[printer_id captured_at]
    add_index :photo_captures, %i[job_id captured_at]
  end
end
