class User < ApplicationRecord
  has_many :owned_jobs, class_name: 'Job', foreign_key: :owner_id, dependent: :nullify, inverse_of: :owner
  has_many :cleared_jobs, class_name: 'Job', foreign_key: :cleared_by_id, dependent: :nullify, inverse_of: :cleared_by

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validate :slack_id_required_for_slack_notifications

  normalizes :email, with: ->(value) { value.to_s.downcase.strip }
  normalizes :slack_handle, with: ->(value) { value.to_s.strip.delete_prefix('@').presence }
  normalizes :slack_id, with: ->(value) { value.to_s.strip.presence }

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

  def email_notifications_available?
    MailConfig.configured? && email.present?
  end

  def slack_notifications_available?
    SlackConfig.configured? && slack_id.present?
  end

  def wants_email_notifications?
    notify_via_email? && email_notifications_available?
  end

  def wants_slack_notifications?
    notify_via_slack? && slack_notifications_available?
  end

  private

  def slack_id_required_for_slack_notifications
    return unless notify_via_slack?
    return if slack_id.present?

    errors.add(:notify_via_slack, 'requires a Slack user ID')
  end
end
