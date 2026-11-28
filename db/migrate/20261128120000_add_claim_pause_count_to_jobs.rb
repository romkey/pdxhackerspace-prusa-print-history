# How many times PrintStartHolds has paused a print because nobody claimed it. Past
# Setting.claim_hold_max_pauses the print is cancelled instead of paused again.
class AddClaimPauseCountToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :claim_pause_count, :integer, default: 0, null: false
  end
end
