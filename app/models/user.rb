class User < ApplicationRecord
  has_many :owned_jobs, class_name: 'Job', foreign_key: :owner_id, dependent: :nullify, inverse_of: :owner

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }

  normalizes :email, with: ->(value) { value.to_s.downcase.strip }
  normalizes :slack_handle, with: ->(value) { value.to_s.strip.delete_prefix('@').presence }

  def self.find_or_create_from_auth(auth)
    user = find_or_initialize_by(provider: auth.provider, uid: auth.uid)
    user.email = auth.info.email
    user.name  = auth.info.name.presence || auth.info.email
    user.admin = true if AdminEmails.include?(user.email)
    user.save!
    user
  end

  def display_name
    name.presence || email
  end
end
