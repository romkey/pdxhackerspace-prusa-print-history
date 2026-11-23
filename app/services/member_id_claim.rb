# Syncs the Authentik `member_id` claim, a stable member identifier that does not change
# with email or username, to users.member_id at sign-in. A kiosk resolves a keyfob to this
# ID by its own means and passes it to the API; this app never sees fob numbers.
module MemberIdClaim
  CLAIM = 'member_id'.freeze

  module_function

  # Sets the user's member_id from the claims, or clears it when the claim is missing. If
  # another account holds the same ID, the newer sign-in wins and the older account loses it.
  def apply(user, claims)
    return unless user.provider == 'authentik'

    value = normalize(claims[CLAIM])
    release_from_others!(user, value) if value
    user.member_id = value
  end

  def normalize(value)
    value.to_s.strip.presence
  end

  def release_from_others!(user, value)
    User.where(member_id: value).where.not(id: user.id).find_each do |other|
      Rails.logger.warn("[member_id] moved from user #{other.id} to user #{user.id || 'new'}")
      other.update!(member_id: nil)
    end
  end
end
