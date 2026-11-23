require 'test_helper'

class LoginLinkTest < ActiveSupport::TestCase
  def build_link(**attributes)
    LoginLink.create!(user: users(:viewer), expires_at: 10.minutes.from_now, **attributes)
  end

  test 'stores only a digest and is found by its secret' do
    link = build_link

    assert_equal LoginLink.digest(link.secret), link.token_digest
    assert_equal link, LoginLink.for_secret(link.secret)
    assert_nil LoginLink.for_secret('nope')
    assert_nil LoginLink.for_secret(nil)
  end

  test 'return paths are limited to this app' do
    assert_equal '/jobs', LoginLink.safe_return_to('/jobs')
    assert_equal '/', LoginLink.safe_return_to('https://evil.example')
    assert_equal '/', LoginLink.safe_return_to('//evil.example')
    assert_equal '/', LoginLink.safe_return_to('/\\evil.example')
    assert_equal '/', build_link(return_to: 'http://evil.example').return_to
  end

  test 'consume works once and not after expiry' do
    link = build_link

    assert_equal link, link.consume
    assert_nil link.consume
    assert_not link.usable?

    expired = build_link(expires_at: 1.second.ago)

    assert_nil expired.consume
  end
end
