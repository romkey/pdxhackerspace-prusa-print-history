class AddSlackHandleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :slack_handle, :string
  end
end
