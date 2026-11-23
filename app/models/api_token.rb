# A bearer credential for the JSON API. Only a SHA-256 digest of the secret is stored; the
# secret itself exists in memory just long enough to be shown once after create or rotate.
# What a token may do is decided at request time by ApiTokenAuthenticator, from the owner's
# current role, the token's access level and the API settings.
class ApiToken < ApplicationRecord
  ACCESS_LEVELS = %w[read read_write read_write_delete].freeze
  ACCESS_LEVEL_LABELS = {
    'read' => 'Read only',
    'read_write' => 'Read and write',
    'read_write_delete' => 'Read, write and delete'
  }.freeze
  KINDS = %w[personal device].freeze
  STATES = %w[active paused expired revoked].freeze
  SECRET_PREFIX = 'pph_'.freeze
  DISPLAY_PREFIX_LENGTH = 12
  LAST_USED_RESOLUTION = 1.minute

  belongs_to :user
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :events, -> { order(occurred_at: :desc) }, class_name: 'ApiTokenEvent', dependent: :nullify,
                                                      inverse_of: :api_token

  attr_reader :secret

  before_validation :generate_secret, on: :create

  validates :name, presence: true, length: { maximum: 100 }
  validates :kind, inclusion: { in: KINDS }
  validates :access_level, inclusion: { in: ACCESS_LEVELS }
  validates :token_digest, presence: true, uniqueness: true
  validates :token_prefix, presence: true
  validate :allowed_cidrs_are_valid

  scope :recent, -> { order(created_at: :desc) }
  scope :not_revoked, -> { where(revoked_at: nil) }

  def self.digest(secret)
    OpenSSL::Digest::SHA256.hexdigest(secret.to_s)
  end

  def self.authenticate_secret(secret)
    return nil unless secret.is_a?(String) && secret.start_with?(SECRET_PREFIX)

    find_by(token_digest: digest(secret))
  end

  def self.level_rank(level)
    ACCESS_LEVELS.index(level.to_s)
  end

  # The lower of two access levels.
  def self.min_level(first, second)
    [first, second].compact.min_by { |level| level_rank(level) || -1 }
  end

  def state(at = Time.current)
    return 'revoked' if revoked?
    return 'expired' if expired?(at)
    return 'paused' if paused?

    'active'
  end

  def active?(at = Time.current)
    state(at) == 'active'
  end

  def revoked?
    revoked_at.present?
  end

  def paused?
    paused_at.present?
  end

  def expired?(at = Time.current)
    expires_at.present? && expires_at <= at
  end

  def device?
    kind == 'device'
  end

  def access_level_label
    ACCESS_LEVEL_LABELS.fetch(access_level, access_level)
  end

  def allows_ip?(ip)
    return true if allowed_cidrs.blank?

    address = IPAddr.new(ip.to_s)
    allowed_cidrs.any? { |cidr| IPAddr.new(cidr).include?(address) }
  rescue IPAddr::Error
    false
  end

  # Accepts a list or a comma/whitespace separated string, as typed in the token form.
  def allowed_cidrs_text=(value)
    self.allowed_cidrs = value.to_s.split(/[\s,]+/).map(&:strip).compact_blank.uniq
  end

  def allowed_cidrs_text
    allowed_cidrs.join(', ')
  end

  def regenerate_secret
    generate_secret
  end

  # Written at most once a minute per address so a busy client does not turn every read
  # into a write.
  def record_use!(ip, at: Time.current)
    return if last_used_at.present? && last_used_at > at - LAST_USED_RESOLUTION && last_used_ip == ip

    update_columns(last_used_at: at, last_used_ip: ip) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  def generate_secret
    @secret = "#{SECRET_PREFIX}#{SecureRandom.base58(32)}"
    self.token_digest = self.class.digest(@secret)
    self.token_prefix = @secret.first(DISPLAY_PREFIX_LENGTH)
  end

  def allowed_cidrs_are_valid
    Array(allowed_cidrs).each do |cidr|
      IPAddr.new(cidr)
    rescue IPAddr::Error
      errors.add(:allowed_cidrs, "contains an invalid address or range: #{cidr}")
    end
  end
end
