# Claim and filament enforcement settings, mixed into Setting with `extend` so they read as
# Setting.enforce_claims?, Setting.claim_hold_max_pauses, and so on.
module EnforcementSettings
  KEYS = %w[enforce_claims enforce_claims_webhook_url claim_hold_max_pauses enforce_filament_types].freeze

  DEFAULT_CLAIM_HOLD_MAX_PAUSES = 3

  # When on, only members trained on the printers (and admins) may claim, and an unclaimed
  # print is paused whenever the poller finds it printing, until someone claims it.
  def enforce_claims?
    fetch(:enforce_claims) == 'true'
  end

  def enforce_claims=(value)
    set(:enforce_claims, ActiveModel::Type::Boolean.new.cast(value) ? 'true' : 'false')
  end

  # When on, a print whose filament the printer can't run (see FilamentType#allowed_on?) is
  # paused when it starts.
  def enforce_filament_types?
    fetch(:enforce_filament_types) == 'true'
  end

  def enforce_filament_types=(value)
    set(:enforce_filament_types, ActiveModel::Type::Boolean.new.cast(value) ? 'true' : 'false')
  end

  # How many times an unclaimed print is paused for a claim before continuing it again
  # cancels it.
  def claim_hold_max_pauses
    positive_integer_for(:claim_hold_max_pauses, DEFAULT_CLAIM_HOLD_MAX_PAUSES)
  end

  def claim_hold_max_pauses=(value)
    set(:claim_hold_max_pauses, value.presence)
  end

  # Optional URL that gets a JSON POST whenever a print is paused, continued or
  # cancelled for claim or filament enforcement.
  def enforce_claims_webhook_url
    fetch(:enforce_claims_webhook_url).presence
  end

  def enforce_claims_webhook_url=(value)
    set(:enforce_claims_webhook_url, value.to_s.strip.presence)
  end
end
