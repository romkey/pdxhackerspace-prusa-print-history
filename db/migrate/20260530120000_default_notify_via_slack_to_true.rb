class DefaultNotifyViaSlackToTrue < ActiveRecord::Migration[8.1]
  def change
    change_column_default :users, :notify_via_slack, from: false, to: true
  end
end
