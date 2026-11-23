# users.member_id is unique. When a sign-in gives this user an ID another account holds, the
# other account gives it up in a before_save callback, which runs inside the save's
# transaction: if this save fails, the other account keeps its ID.
module MemberIdentity
  extend ActiveSupport::Concern

  included do
    before_save :release_member_id_from_other_accounts, if: -> { member_id.present? && will_save_change_to_member_id? }
  end

  private

  def release_member_id_from_other_accounts
    User.where(member_id:).where.not(id:).find_each do |other|
      logger.warn("[member_id] moved from user #{other.id} to user #{id || 'new'}")
      other.update!(member_id: nil)
    end
  end
end
