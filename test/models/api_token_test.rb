require 'test_helper'

class ApiTokenTest < ActiveSupport::TestCase
  test 'a new token gets a prefixed secret, stores only its digest, and can be found by it' do
    token = create_api_token(users(:viewer))

    assert_match(/\Apph_[1-9A-HJ-NP-Za-km-z]{32}\z/, token.secret)
    assert_equal ApiToken.digest(token.secret), token.token_digest
    assert_equal token.secret.first(12), token.token_prefix
    assert_equal token, ApiToken.authenticate_secret(token.secret)
    assert_nil ApiToken.find(token.id).secret
  end

  test 'authenticate_secret ignores secrets without the prefix or that do not match' do
    create_api_token(users(:viewer))

    assert_nil ApiToken.authenticate_secret('not-a-token')
    assert_nil ApiToken.authenticate_secret('pph_doesnotexist')
    assert_nil ApiToken.authenticate_secret(nil)
  end

  test 'regenerating the secret invalidates the old one' do
    token = create_api_token(users(:viewer))
    old_secret = token.secret

    token.regenerate_secret
    token.save!

    assert_nil ApiToken.authenticate_secret(old_secret)
    assert_equal token, ApiToken.authenticate_secret(token.secret)
  end

  test 'state reflects revoked, expired, paused and active in that order' do
    token = create_api_token(users(:viewer))

    assert_equal 'active', token.state

    token.paused_at = Time.current

    assert_equal 'paused', token.state

    token.expires_at = 1.minute.ago

    assert_equal 'expired', token.state

    token.revoked_at = Time.current

    assert_equal 'revoked', token.state
  end

  test 'allowed addresses accept a typed list and restrict use' do
    token = create_api_token(users(:viewer))

    assert token.allows_ip?('203.0.113.9')

    token.allowed_cidrs_text = '192.168.1.0/24,  10.0.0.5'

    assert_equal %w[192.168.1.0/24 10.0.0.5], token.allowed_cidrs
    assert token.allows_ip?('192.168.1.44')
    assert token.allows_ip?('10.0.0.5')
    assert_not token.allows_ip?('10.0.0.6')
    assert_not token.allows_ip?('garbage')
  end

  test 'invalid address ranges are rejected' do
    token = ApiToken.new(user: users(:viewer), name: 'x', access_level: 'read')
    token.allowed_cidrs_text = '192.168.1.0/24, not-an-ip'

    assert_not token.valid?
    assert_match(/not-an-ip/, token.errors.full_messages.to_sentence)
  end

  test 'record_use! writes at most once a minute from the same address' do
    token = create_api_token(users(:viewer))
    now = Time.current

    token.record_use!('10.0.0.1', at: now)
    token.record_use!('10.0.0.1', at: now + 30.seconds)

    assert_in_delta now, token.reload.last_used_at, 1

    token.record_use!('10.0.0.2', at: now + 31.seconds)

    assert_equal '10.0.0.2', token.reload.last_used_ip
  end

  test 'min_level picks the lower access level' do
    assert_equal 'read', ApiToken.min_level('read_write_delete', 'read')
    assert_equal 'read_write', ApiToken.min_level('read_write', 'read_write_delete')
  end

  test 'deleting a user deletes their tokens' do
    user = users(:other_viewer)
    create_api_token(user)

    assert_difference -> { ApiToken.count }, -1 do
      user.destroy!
    end
  end
end
