# A single-use sign-in link, requested through the API and delivered by email (or shown on a
# kiosk as a QR code). Only a digest of the secret is stored. Opening the link shows a
# confirmation page; the sign-in itself happens on POST, so mail scanners that prefetch
# links cannot use them up.
class LoginLink < ApplicationRecord
  DELIVERIES = %w[email display].freeze
  REQUESTS_PER_PERIOD = 3
  REQUEST_PERIOD = 15.minutes

  belongs_to :user
  belongs_to :requested_by_token, class_name: 'ApiToken', optional: true

  attr_reader :secret

  before_validation :generate_secret, on: :create

  validates :token_digest, presence: true, uniqueness: true
  validates :delivery, inclusion: { in: DELIVERIES }
  validates :expires_at, presence: true
  validates :return_to, presence: true

  def self.digest(secret)
    OpenSSL::Digest::SHA256.hexdigest(secret.to_s)
  end

  def self.for_secret(secret)
    return nil if secret.blank?

    find_by(token_digest: digest(secret))
  end

  # Only paths on this app; anything else falls back to the home page.
  def self.safe_return_to(path)
    path = path.to_s
    return '/' unless path.start_with?('/') && !path.start_with?('//') && path.exclude?('\\')

    path
  end

  def self.recently_requested_count(user, at: Time.current)
    where(user:).where(created_at: (at - REQUEST_PERIOD)..).count
  end

  def usable?(at = Time.current)
    used_at.nil? && expires_at > at
  end

  # Marks the link used and returns it, or returns nil if it was already used or has
  # expired, including when two requests race to use it.
  def consume(at = Time.current)
    consumed = self.class.where(id:, used_at: nil).where('expires_at > ?', at)
                   .update_all(used_at: at, updated_at: at) # rubocop:disable Rails/SkipsModelValidations
    reload
    consumed == 1 ? self : nil
  end

  private

  def generate_secret
    @secret = SecureRandom.urlsafe_base64(32)
    self.token_digest = self.class.digest(@secret)
    self.return_to = self.class.safe_return_to(return_to)
  end
end
