require 'test_helper'

class MemberIdClaimTest < ActiveSupport::TestCase
  def auth_for(user, member_id: nil)
    raw_info = member_id.nil? ? {} : { member_id: }
    OmniAuth::AuthHash.new(provider: user.provider, uid: user.uid,
                           info: { email: user.email, name: user.name, nickname: user.username },
                           extra: { raw_info: })
  end

  test 'sign-in stores the member_id claim, trimmed' do
    user = User.find_or_create_from_auth(auth_for(users(:viewer), member_id: '  ak-member-42 '))

    assert_equal 'ak-member-42', user.member_id
    assert_equal user, User.find_by(member_id: 'ak-member-42')
  end

  test 'a sign-in without the claim clears it' do
    users(:viewer).update!(member_id: 'ak-member-42')

    user = User.find_or_create_from_auth(auth_for(users(:viewer)))

    assert_nil user.member_id
  end

  test 'the newer sign-in takes over an ID held by another account' do
    users(:other_viewer).update!(member_id: 'ak-member-42')

    User.find_or_create_from_auth(auth_for(users(:viewer), member_id: 'ak-member-42'))

    assert_equal 'ak-member-42', users(:viewer).reload.member_id
    assert_nil users(:other_viewer).reload.member_id
  end

  test 'non-Authentik accounts are left alone' do
    user = User.new(provider: 'developer', member_id: 'keep')

    MemberIdClaim.apply(user, { 'member_id' => 'other' })

    assert_equal 'keep', user.member_id
  end
end
