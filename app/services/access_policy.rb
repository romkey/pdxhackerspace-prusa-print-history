# Who may do what to a print. The web controllers and the JSON API both ask this object, so
# the two can never disagree. `user` is the signed-in user (or the API token's owner);
# `internal_network` is whether the request comes from INTERNAL_NETWORKS.
class AccessPolicy
  attr_reader :user

  # `admin_allowed: false` treats an admin as a member, for kiosk sessions: a shared kiosk
  # never gets admin powers, whoever scanned in. `undo_allowed: false` takes away undoing a
  # clear, which kiosk sessions cannot do.
  def initialize(user:, internal_network: false, admin_allowed: true, undo_allowed: true)
    @user = user
    @internal_network = internal_network
    @admin_allowed = admin_allowed
    @undo_allowed = undo_allowed
  end

  def signed_in?
    user.present?
  end

  def admin?
    (@admin_allowed && user&.admin?) || false
  end

  def internal_network?
    @internal_network
  end

  # Filename, owner, progress and photos of a private print: its owner and admins only. Uses
  # admin? so a kiosk session never reveals them, even when an admin scanned in.
  def can_see_details?(job)
    return true unless job.private?
    return false unless signed_in?

    admin? || job.owner_id == user.id
  end

  # Members claim unclaimed prints, or re-claim their own to switch between public and
  # private. Taking over someone else's claim is an admin-only reassignment. While claims
  # are enforced, a member must have every training topic the printer requires to claim a
  # print they don't own yet.
  def can_claim?(job)
    return false unless signed_in?
    return true if admin? || job.owner_id == user.id

    job.owner_id.nil? && trained_for?(job.printer)
  end

  # Why can_claim? refuses a print, for error messages: :untrained or :claimed.
  def claim_refusal(job)
    return nil if can_claim?(job)
    return :claimed if job.owner_id.present?

    :untrained
  end

  def claim_refusal_message(job)
    case claim_refusal(job)
    when :claimed then 'This print is already claimed by someone else.'
    when :untrained
      "Only members trained on #{job.printer.required_training.to_sentence} can claim prints on #{job.printer.name}."
    end
  end

  def trained_for?(printer)
    return false unless signed_in?
    return true if admin? || !Setting.enforce_claims?

    user.trained_for?(printer.required_training)
  end

  def can_release_claim?(job)
    return false unless signed_in? && job.owner_id.present?

    job.owner_id == user.id || admin?
  end

  # Any member may clear prints. Anonymous visitors may too, but only from the shop network.
  def can_clear_prints?
    signed_in? || internal_network?
  end

  def can_clear?(job)
    can_clear_prints? && job.clearable?
  end

  # Undoing a clear is for admins, and for members when the members_can_undo_clear setting
  # is on. Never for anonymous visitors.
  def can_undo_clears?
    return false unless @undo_allowed
    return true if admin?

    signed_in? && Setting.members_can_undo_clear?
  end

  def can_undo_clear?(job)
    can_undo_clears? && job.cleared?
  end

  def can_report_problems?
    signed_in? || internal_network?
  end
end
