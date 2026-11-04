# The single Prusa Account login used to read from the Prusa Connect web API (as opposed to
# the per-printer camera token on Printer). An admin pastes a refresh token; access tokens are
# minted from it on demand and the rotated refresh token is persisted.
class PrusaConnectCredential < ApplicationRecord
  encrypts :refresh_token, :access_token

  EXPIRY_LEEWAY = 60.seconds

  def self.current
    first
  end

  def self.current!
    first_or_create!
  end

  def configured?
    refresh_token.present?
  end

  def access_token_fresh?
    access_token.present? && access_token_expires_at.present? && access_token_expires_at > EXPIRY_LEEWAY.from_now
  end

  def store_tokens!(access_token:, expires_in:, refresh_token: nil)
    update!(
      access_token: access_token,
      access_token_expires_at: Time.current + expires_in.to_i.seconds,
      refresh_token: refresh_token.presence || self.refresh_token,
      last_error: nil
    )
  end

  def record_error!(message)
    update!(last_error: message.to_s.truncate(500))
  end

  def reset_with_refresh_token!(token)
    update!(refresh_token: token.strip, access_token: nil, access_token_expires_at: nil, last_error: nil)
  end
end
