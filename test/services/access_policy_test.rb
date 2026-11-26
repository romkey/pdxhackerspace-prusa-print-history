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

  test 'while claims are enforced members need every topic the printer requires' do
    Setting.enforce_claims = true
    @job.printer.update!(required_training: %w[Prusa XL])
    @job.update!(owner: nil)
    @member.update!(trained_on: %w[prusa])
    @other.update!(trained_on: %w[Prusa xl Laser])

    assert_not policy(@member).can_claim?(@job)
    assert_equal :untrained, policy(@member).claim_refusal(@job)
    assert_equal 'Only members trained on Prusa and XL can claim prints on Prusa XL.',
                 policy(@member).claim_refusal_message(@job)
    assert policy(@other).can_claim?(@job)
    assert policy(@admin).can_claim?(@job)

    @job.update!(owner: @member)

    assert policy(@member).can_claim?(@job), 'an owner can still switch their claim to private'
    assert_equal :claimed, policy(@other).claim_refusal(@job)
  end

  test 'a printer that requires no training lets any member claim while claims are enforced' do
    Setting.enforce_claims = true
    @job.printer.update!(required_training: [])
    @job.update!(owner: nil)
    @member.update!(trained_on: [])

    assert policy(@member).can_claim?(@job)
  end

  test 'a printer exempted from claim enforcement lets untrained members claim' do
    Setting.enforce_claims = true
    @job.printer.update!(required_training: %w[Prusa], enforce_claims: false)
    @job.update!(owner: nil)
    @member.update!(trained_on: [])

    assert policy(@member).can_claim?(@job)
  end

  test 'untrained members can claim when claims are not enforced' do
    @job.update!(owner: nil)
    @member.update!(trained_on: [])

    assert_not Setting.enforce_claims?
    assert policy(@member).can_claim?(@job)
  end
end
