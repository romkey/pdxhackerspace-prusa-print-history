require 'test_helper'

class PrusaTrainingNoticeTest < ActiveSupport::TestCase
  test 'returns both default messages when member lacks Prusa training' do
    auth = authentik_auth(trained_on: ['Laser'])
    user = users(:viewer)

    message = PrusaTrainingNotice.for_auth(auth, user: user)

    assert_includes message, Setting::DEFAULT_PRUSA_UNTRAINED_MESSAGE
    assert_includes message, Setting::DEFAULT_PRUSA_TRAINED_ACCOUNT_MESSAGE
  end

  test 'returns nothing when member is trained on Prusa' do
    auth = authentik_auth(trained_on: %w[Laser Prusa])
    user = users(:viewer)

    assert_nil PrusaTrainingNotice.for_auth(auth, user: user)
  end

  test 'matches Prusa training case-insensitively' do
    auth = authentik_auth(trained_on: ['prusa'])
    user = users(:viewer)

    assert_nil PrusaTrainingNotice.for_auth(auth, user: user)
  end

  test 'returns nothing for admins' do
    auth = authentik_auth(trained_on: [])
    user = users(:admin)

    assert_nil PrusaTrainingNotice.for_auth(auth, user: user)
  end

  test 'returns nothing for non-authentik providers' do
    auth = OmniAuth::AuthHash.new(
      provider: 'developer',
      uid: 'dev@example.com',
      info: { email: 'dev@example.com', name: 'Dev User' }
    )
    user = users(:viewer)

    assert_nil PrusaTrainingNotice.for_auth(auth, user: user)
  end

  test 'uses configured messages from settings' do
    Setting.set(:prusa_untrained_message, 'Custom untrained warning.')
    Setting.set(:prusa_trained_account_message, 'Custom account warning.')

    auth = authentik_auth(trained_on: [])
    user = users(:viewer)

    message = PrusaTrainingNotice.for_auth(auth, user: user)

    assert_equal "Custom untrained warning.\n\nCustom account warning.", message
  end

  test 'omits blank configured messages' do
    Setting.set(:prusa_untrained_message, 'Only untrained.')
    Setting.set(:prusa_trained_account_message, '')

    auth = authentik_auth(trained_on: [])
    user = users(:viewer)

    assert_equal 'Only untrained.', PrusaTrainingNotice.for_auth(auth, user: user)
  end

  private

  def authentik_auth(trained_on:)
    OmniAuth::AuthHash.new(
      provider: 'authentik',
      uid: 'trained-on-uid',
      info: { email: 'trained@example.com', name: 'Trained User' },
      extra: { raw_info: { trained_on: trained_on } }
    )
  end
end
