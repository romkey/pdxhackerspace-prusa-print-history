require 'test_helper'

class SlackMessengerTest < ActiveSupport::TestCase
  test 'dm raises when token missing' do
    assert_raises(Slack::Messenger::Error) do
      Slack::Messenger.new(token: nil).dm(handle: 'alice', text: 'hello')
    end
  end

  test 'dm posts to chat.postMessage with @ handle' do
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    captured = nil
    messenger.stub(:post, lambda { |payload|
      captured = payload
      { 'ok' => true }
    }) do
      messenger.dm(handle: 'alice', text: 'Your print is ready')
    end

    assert_equal '@alice', captured[:channel]
    assert_equal 'Your print is ready', captured[:text]
  end

  test 'dm raises on slack api error' do
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    messenger.stub(:post, { 'ok' => false, 'error' => 'channel_not_found' }) do
      error = assert_raises(Slack::Messenger::Error) do
        messenger.dm(handle: 'missing', text: 'hi')
      end
      assert_equal 'channel_not_found', error.message
    end
  end
end
