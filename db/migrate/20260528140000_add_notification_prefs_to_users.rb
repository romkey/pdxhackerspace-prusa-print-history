class AddNotificationPrefsToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string :slack_id
      t.boolean :notify_via_email, default: true, null: false
      t.boolean :notify_via_slack, default: false, null: false
    end
  end
end
