# Syncs the Authentik `member_id` claim, a stable member identifier that does not change
# with email or username, to users.member_id at sign-in. A kiosk resolves a keyfob to this
# ID by its own means and passes it to the API; this app never sees fob numbers.
module MemberIdClaim
  CLAIM = 'member_id'.freeze

  module_function

  # Sets the user's member_id from the claims, or clears it when the claim is missing. If
  # another account holds the same ID, the newer sign-in wins: MemberIdentity takes it from
  # the older account inside the same save, so a failed sign-in leaves both untouched.
  def apply(user, claims)
    return unless user.provider == 'authentik'

    user.member_id = normalize(claims[CLAIM])
  end

  def normalize(value)
    value.to_s.strip.presence
  end
end
