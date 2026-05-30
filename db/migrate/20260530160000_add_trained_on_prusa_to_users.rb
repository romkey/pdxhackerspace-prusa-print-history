class AddTrainedOnPrusaToUsers < ActiveRecord::Migration[8.1]
  def change
    # Null until the user signs in via Authentik and we read trained_on from OIDC claims.
    add_column :users, :trained_on_prusa, :boolean, null: true # rubocop:disable Rails/ThreeStateBooleanColumn
  end
end
