# Issues and manages API tokens on behalf of a signed-in user, enforcing ApiTokenRules and
# writing an ApiTokenEvent for every change. Raises ApiTokenLifecycle::Error with a message
# fit to show the user.
class ApiTokenLifecycle
  class Error < StandardError; end

  def initialize(actor:, ip: nil)
    @actor = actor
    @ip = ip
  end

  def issue!(owner:, name:, access_level:, expires_in_days: nil, allowed_cidrs_text: '')
    raise Error, 'You cannot create tokens for this user.' unless ApiTokenRules.can_create_for?(@actor, owner)
    raise Error, 'That access level is not allowed for this user.' unless level_allowed?(owner, access_level)

    days = lifetime_days_for(owner, expires_in_days)
    token = ApiToken.new(user: owner, created_by: @actor, name: name.to_s.strip, access_level: access_level.to_s,
                         lifetime_days: days, expires_at: days&.days&.from_now)
    token.allowed_cidrs_text = allowed_cidrs_text
    save_with_event!(token, 'created', access_level: token.access_level, expires_at: token.expires_at&.iso8601)
  end

  def pause!(token)
    authorize!(token)
    raise Error, 'This token is revoked.' if token.revoked?
    raise Error, 'This token is already paused.' if token.paused?

    token.paused_at = Time.current
    save_with_event!(token, 'paused')
  end

  def resume!(token)
    authorize!(token)
    raise Error, 'This token is revoked.' if token.revoked?
    raise Error, 'This token is not paused.' unless token.paused?

    token.paused_at = nil
    save_with_event!(token, 'resumed')
  end

  # Extends the expiry from now by the lifetime the token was issued with, capped by the
  # current maximum. A token that never expires has nothing to renew.
  def renew!(token)
    authorize!(token)
    raise Error, 'This token does not expire.' if token.expires_at.nil?
    raise Error, 'This token can no longer be renewed.' unless ApiTokenRules.renewable?(token)

    days = ApiTokenRules.renewal_days_for(token)
    token.expires_at = days.days.from_now
    save_with_event!(token, 'renewed', expires_at: token.expires_at.iso8601)
  end

  def rotate!(token)
    authorize!(token)
    raise Error, 'This token is revoked.' if token.revoked?

    token.regenerate_secret
    save_with_event!(token, 'rotated')
  end

  def revoke!(token)
    authorize!(token)
    raise Error, 'This token is already revoked.' if token.revoked?

    token.revoked_at = Time.current
    save_with_event!(token, 'revoked')
  end

  private

  def authorize!(token)
    raise Error, 'You cannot manage this token.' unless ApiTokenRules.can_manage?(@actor, token)
  end

  def level_allowed?(owner, level)
    ApiTokenRules.levels_for(owner).include?(level.to_s)
  end

  # Blank means "never expires" (nil), which is only allowed when no maximum lifetime is set.
  def lifetime_days_for(owner, expires_in_days)
    max = ApiTokenRules.max_days_for(owner)
    if expires_in_days.blank?
      raise Error, "Tokens for this user must expire within #{max} days." unless max.nil?

      return nil
    end

    days = Integer(expires_in_days.to_s, 10, exception: false)
    raise Error, 'Expiry must be a whole number of days.' if days.nil? || !days.positive?
    raise Error, "Tokens for this user must expire within #{max} days." if max && days > max

    days
  end

  def save_with_event!(token, action, detail = {})
    ApiToken.transaction do
      token.save!
      ApiTokenEvent.record!(action:, token:, actor: @actor, subject: token.user, ip: @ip, detail: detail.compact)
    end
    token
  rescue ActiveRecord::RecordInvalid => e
    raise Error, e.record.errors.full_messages.to_sentence
  end
end
