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
    claims = auth_claims(auth)
    apply_admin_from_auth(user, claims)
    apply_slack_from_auth(user, claims)
    user.save!
    user
  end

  def self.apply_admin_from_auth(user, claims)
    if claims.key?('is_admin')
      user.admin = truthy?(claims['is_admin'])
    elsif AdminEmails.include?(user.email)
      user.admin = true
    end
  end

  def self.apply_slack_from_auth(user, claims)
    if claims.key?('slack')
      apply_slack_hash(user, claims['slack'])
    elsif claims.key?('has_slack') && !truthy?(claims['has_slack'])
      clear_slack!(user)
    end
  end

  def self.apply_slack_hash(user, slack)
    return clear_slack!(user) unless slack.is_a?(Hash)

    slack_id = claim_value(slack, 'uid')
    if slack_id.blank?
      clear_slack!(user)
    else
      user.slack_id = slack_id
      user.slack_handle = claim_value(slack, 'name')
    end
  end

  def self.clear_slack!(user)
    user.slack_id = nil
    user.slack_handle = nil
    user.notify_via_slack = false if user.notify_via_slack?
  end

  def self.claim_value(source, key)
    value = source[key] || source[key.to_sym]
    value.to_s.strip.presence
  end

  def self.truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def self.auth_claims(auth)
    sources = [auth.info, auth.extra&.raw_info].compact
    sources.each_with_object({}) do |source, claims|
      next unless source.respond_to?(:[])

      source.each do |key, value|
        claims[key.to_s] = value if claim_value_present?(value)
      end
    end
  end

  def self.claim_value_present?(value)
    return true if value.is_a?(TrueClass) || value.is_a?(FalseClass)

    value.present?
  end
  private_class_method :apply_admin_from_auth, :apply_slack_from_auth, :apply_slack_hash, :clear_slack!,
                       :claim_value, :claim_value_present?, :truthy?, :auth_claims

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
