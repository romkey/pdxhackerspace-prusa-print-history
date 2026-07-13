class EncryptSensitiveDataAtRest < ActiveRecord::Migration[8.1]
  def up
    widen_user_pii_columns
    encrypt_existing_records
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def widen_user_pii_columns
    change_column :users, :email, :text, null: false
    change_column :users, :name, :text
    change_column :users, :username, :text
    change_column :users, :slack_handle, :text
    change_column :users, :slack_id, :text
  end

  def encrypt_existing_records
    with_unencrypted_support do
      say_with_time 'Encrypting user PII' do
        User.reset_column_information
        User.find_each do |user|
          user.encrypt
          user.save!(validate: false)
        end
      end

      say_with_time 'Encrypting printer credentials' do
        Printer.reset_column_information
        Printer.find_each do |printer|
          printer.encrypt
          printer.save!(validate: false)
        end
      end
    end
  end

  def with_unencrypted_support
    original = ActiveRecord::Encryption.config.support_unencrypted_data
    ActiveRecord::Encryption.config.support_unencrypted_data = true
    yield
  ensure
    ActiveRecord::Encryption.config.support_unencrypted_data = original
  end
end
