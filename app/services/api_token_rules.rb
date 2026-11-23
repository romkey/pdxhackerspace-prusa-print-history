# Settings-driven rules for API tokens: lifetimes, access levels, and who may issue or
# manage which tokens. Everything here is read from Setting at call time, so a settings
# change applies to existing tokens on their next use.
module ApiTokenRules
  module_function

  def admin_owner?(owner)
    owner&.admin? || false
  end

  # Days a new or renewed token lives by default. nil means it does not expire.
  def default_days_for(owner)
    default = admin_owner?(owner) ? Setting.api_admin_token_default_days : Setting.api_member_token_default_days
    max = max_days_for(owner)
    return max if default.nil?
    return default if max.nil?

    [default, max].min
  end

  # The longest lifetime a token may be given. nil means no limit, including no expiry.
  def max_days_for(owner)
    admin_owner?(owner) ? Setting.api_admin_token_max_days : Setting.api_member_token_max_days
  end

  def never_expires_allowed?(owner)
    max_days_for(owner).nil?
  end

  # Access levels a token for this owner may be issued with.
  def levels_for(owner)
    return ApiToken::ACCESS_LEVELS if admin_owner?(owner)

    cap = ApiToken.level_rank(Setting.api_member_max_access_level)
    ApiToken::ACCESS_LEVELS.select { |level| ApiToken.level_rank(level) <= cap }
  end

  # The level a token actually has right now: its own level, capped for members by the
  # current setting. A member promoted to admin gets the token's full level; an admin
  # demoted to member gets the cap.
  def effective_level(token)
    return token.access_level if admin_owner?(token.user)

    ApiToken.min_level(token.access_level, Setting.api_member_max_access_level)
  end

  def can_create_for?(actor, owner)
    return false if actor.nil? || owner.nil?
    return true if actor.admin?

    actor == owner && Setting.api_members_can_create_tokens?
  end

  def can_create_any?(actor)
    return false if actor.nil?

    actor.admin? || Setting.api_members_can_create_tokens?
  end

  def can_manage?(actor, token)
    return false if actor.nil?

    actor.admin? || token.user_id == actor.id
  end

  def renewable?(token, at: Time.current)
    return false if token.revoked?
    return true unless token.expired?(at)

    grace = Setting.api_token_renew_grace_days
    grace.present? && token.expires_at > at - grace.days
  end

  def login_too_old?(owner, at: Time.current)
    max_age = Setting.api_token_max_login_age_days
    return false if max_age.nil?

    owner.last_login_at.nil? || owner.last_login_at < at - max_age.days
  end
end
