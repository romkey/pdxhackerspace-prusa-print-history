class AddTrainingTopics < ActiveRecord::Migration[8.1]
  def change
    # Training topics a member must have (all of them) to claim a print on this printer
    # while claims are enforced. Empty means anyone may claim.
    add_column :printers, :required_training, :string, array: true, default: [], null: false
    # Every topic in the member's Authentik trained_on claim at their last sign-in.
    add_column :users, :trained_on, :string, array: true, default: [], null: false

    reversible do |dir|
      dir.up do
        # Keep today's behaviour: enforcement required Prusa training on every printer, Bambu
        # included. Admins can change each printer's requirement afterwards.
        execute "UPDATE printers SET required_training = ARRAY['Prusa']"
        execute "UPDATE users SET trained_on = ARRAY['Prusa'] WHERE trained_on_prusa = TRUE"
      end
    end
  end
end
