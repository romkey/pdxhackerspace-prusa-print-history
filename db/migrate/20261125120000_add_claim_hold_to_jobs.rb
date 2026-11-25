class AddClaimHoldToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :claim_hold_at, :datetime
    add_index :jobs, :claim_hold_at, where: 'claim_hold_at IS NOT NULL'
  end
end
