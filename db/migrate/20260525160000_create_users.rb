class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string  :email,    null: false
      t.string  :name
      t.string  :provider, null: false
      t.string  :uid,      null: false
      t.boolean :admin,    null: false, default: false

      t.timestamps
    end

    add_index :users, %i[provider uid], unique: true
    add_index :users, :email, unique: true
  end
end
