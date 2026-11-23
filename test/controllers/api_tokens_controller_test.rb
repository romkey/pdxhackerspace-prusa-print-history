require 'test_helper'

class ApiTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @member = users(:viewer)
    @admin = users(:admin)
  end

  test 'requires sign-in' do
    get api_tokens_path

    assert_redirected_to login_path
  end

  test 'a member sees only their own tokens' do
    mine = create_api_token(@member, name: 'Mine')
    create_api_token(users(:other_viewer), name: 'Not mine')
    login_as(@member)

    get api_tokens_path

    assert_response :success
    assert_select 'a', text: mine.name
    assert_select 'a', text: 'Not mine', count: 0
  end

  test 'an admin sees everyone\'s tokens' do
    create_api_token(@member, name: 'Ada token')
    login_as(@admin)

    get api_tokens_path

    assert_select 'a', text: 'Ada token'
  end

  test 'creating a token shows its secret once' do
    login_as(@member)

    assert_difference -> { @member.api_tokens.count }, 1 do
      post api_tokens_path, params: { api_token: { name: 'Script', access_level: 'read', expires_in_days: '30' } }
    end

    token = @member.api_tokens.last

    assert_response :success
    assert_equal 'no-store', response.headers['Cache-Control']
    assert_select 'input[data-clipboard-target=source][value^=?]', token.token_prefix

    get api_token_path(token)

    assert_select 'input[data-clipboard-target=source]', count: 0
  end

  test 'the create form and rotate button bypass Turbo, which ignores a rendered secret page' do
    token = create_api_token(@member)
    login_as(@member)

    get new_api_token_path

    assert_select 'form[action=?][data-turbo=false]', api_tokens_path

    get api_token_path(token)

    assert_select 'form[action=?][data-turbo=false]', rotate_api_token_path(token)
  end

  test 'invalid choices re-render the form with the reason' do
    Setting.api_member_token_max_days = '10'
    login_as(@member)

    post api_tokens_path, params: { api_token: { name: 'Script', access_level: 'read', expires_in_days: '50' } }

    assert_response :unprocessable_content
    assert_match(/within 10 days/, response.body)
  end

  test 'members cannot create tokens when self-service is off, and are not offered the button' do
    Setting.api_members_can_create_tokens = false
    login_as(@member)

    get api_tokens_path

    assert_select 'a', text: '+ New token', count: 0

    get new_api_token_path

    assert_response :forbidden

    post api_tokens_path, params: { api_token: { name: 'Script', access_level: 'read', expires_in_days: '5' } }

    assert_response :unprocessable_content
    assert_equal 0, @member.api_tokens.count
  end

  test 'a member cannot create a token for someone else by passing a user id' do
    login_as(@member)

    post api_tokens_path, params: { api_token: { user_id: @admin.id, name: 'Sneaky', access_level: 'read',
                                                 expires_in_days: '5' } }

    assert_equal 0, @admin.api_tokens.count
    assert_equal 1, @member.api_tokens.count
  end

  test 'an admin can create a token for a member' do
    login_as(@admin)

    post api_tokens_path, params: { api_token: { user_id: @member.id, name: 'Kiosk', access_level: 'read',
                                                 expires_in_days: '5' } }

    assert_equal @admin, @member.api_tokens.last.created_by
  end

  test 'pause, resume, renew and revoke from the token page' do
    token = create_api_token(@member, expires_at: 1.day.from_now)
    login_as(@member)

    post pause_api_token_path(token)

    assert_redirected_to api_token_path(token)
    assert token.reload.paused?

    post resume_api_token_path(token)

    assert_not token.reload.paused?

    post renew_api_token_path(token)

    assert_operator token.reload.expires_at, :>, 300.days.from_now

    post revoke_api_token_path(token)

    assert token.reload.revoked?
  end

  test 'rotating shows the new secret' do
    token = create_api_token(@member)
    old_digest = token.token_digest
    login_as(@member)

    post rotate_api_token_path(token)

    assert_response :success
    assert_not_equal old_digest, token.reload.token_digest
    assert_select 'input[data-clipboard-target=source]'
  end

  test 'another member cannot see or change a token' do
    token = create_api_token(users(:other_viewer))
    login_as(@member)

    get api_token_path(token)

    assert_response :forbidden

    post revoke_api_token_path(token)

    assert_response :forbidden
    assert_not token.reload.revoked?
  end
end
