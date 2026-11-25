require 'test_helper'

class AccessPolicyTest < ActiveSupport::TestCase
  setup do
    @job = jobs(:active_xl)
    @member = users(:viewer)
    @other = users(:other_viewer)
    @admin = users(:admin)
  end

  def policy(user, internal: false)
    AccessPolicy.new(user:, internal_network: internal)
  end

  test 'members claim unclaimed prints and their own, but not someone else\'s' do
    @job.update!(owner: nil)

    assert policy(@member).can_claim?(@job)

    @job.update!(owner: @member)

    assert policy(@member).can_claim?(@job)
    assert_not policy(@other).can_claim?(@job)
    assert policy(@admin).can_claim?(@job)
    assert_not policy(nil, internal: true).can_claim?(@job)
  end

  test 'claims are released by their owner or an admin' do
    @job.update!(owner: @member)

    assert policy(@member).can_release_claim?(@job)
    assert policy(@admin).can_release_claim?(@job)
    assert_not policy(@other).can_release_claim?(@job)

    @job.update!(owner: nil)

    assert_not policy(@admin).can_release_claim?(@job)
  end

  test 'any member can clear from anywhere; anonymous visitors only on the shop network' do
    assert policy(@member).can_clear_prints?
    assert policy(nil, internal: true).can_clear_prints?
    assert_not policy(nil).can_clear_prints?
  end

  test 'undoing a clear follows the members_can_undo_clear setting' do
    assert policy(@member).can_undo_clears?

    Setting.members_can_undo_clear = false

    assert_not policy(@member).can_undo_clears?
    assert policy(@admin).can_undo_clears?
    assert_not policy(nil, internal: true).can_undo_clears?
  end

  test 'while claims are enforced only trained members and admins can claim' do
    Setting.enforce_claims = true
    @job.update!(owner: nil)
    @member.update!(trained_on_prusa: false)
    @other.update!(trained_on_prusa: true)

    assert_not policy(@member).can_claim?(@job)
    assert_equal :untrained, policy(@member).claim_refusal(@job)
    assert policy(@other).can_claim?(@job)
    assert policy(@admin).can_claim?(@job)

    @job.update!(owner: @member)

    assert policy(@member).can_claim?(@job), 'an owner can still switch their claim to private'
    assert_equal :claimed, policy(@other).claim_refusal(@job)
  end

  test 'untrained members can claim when claims are not enforced' do
    @job.update!(owner: nil)
    @member.update!(trained_on_prusa: false)

    assert_not Setting.enforce_claims?
    assert policy(@member).can_claim?(@job)
  end
end
