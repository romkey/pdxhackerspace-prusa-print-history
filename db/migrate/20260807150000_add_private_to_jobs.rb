class AddPrivateToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :private, :boolean, null: false, default: false
    add_index :jobs, :private
  end
end
