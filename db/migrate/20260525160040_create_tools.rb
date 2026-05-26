class CreateTools < ActiveRecord::Migration[8.1]
  def change
    create_table :tools do |t|
      t.references :job, null: false, foreign_key: true

      t.integer :tool_index,    null: false
      t.decimal :nozzle_size_mm, precision: 4, scale: 2, null: false
      t.boolean :high_flow, null: false, default: false
      t.string  :material

      t.timestamps
    end

    add_index :tools, %i[job_id tool_index], unique: true
  end
end
