class AddPrusaConnectApiFields < ActiveRecord::Migration[8.1]
  def change
    add_column :printers, :prusa_connect_uuid, :string
    add_index :printers, :prusa_connect_uuid

    add_column :job_events, :connect_detail, :jsonb
  end
end
