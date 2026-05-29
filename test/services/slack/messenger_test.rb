require 'test_helper'

class SlackMessengerTest < ActiveSupport::TestCase
  test 'dm raises when token missing' do
    ENV.delete('SLACK_API_TOKEN')
    assert_raises(Slack::Messenger::Error) do
      Slack::Messenger.new(token: nil).dm(user_id: 'U123', text: 'hello')
    end
  end

  test 'dm posts to chat.postMessage with user id' do
    captured = nil
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    messenger.stub(:post, lambda { |_url, payload|
      captured = payload
      { 'ok' => true }
    }) do
      messenger.dm(user_id: 'U123', text: 'Your print is ready')
    end

    assert_equal 'U123', captured[:channel]
    assert_equal 'Your print is ready', captured[:text]
  end

  test 'dm raises on slack api error' do
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    messenger.stub(:post, { 'ok' => false, 'error' => 'channel_not_found' }) do
      error = assert_raises(Slack::Messenger::Error) do
        messenger.dm(user_id: 'U404', text: 'hi')
      end
      assert_equal 'channel_not_found', error.message
    end
  end
end
