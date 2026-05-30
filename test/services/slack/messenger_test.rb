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

  test 'dm_with_attachment without attachment uses chat.postMessage' do
    captured_url = nil
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    messenger.stub(:post, lambda { |url, _payload|
      captured_url = url
      { 'ok' => true }
    }) do
      messenger.dm_with_attachment(user_id: 'U123', text: 'Text only', attachment: nil)
    end

    assert_equal Slack::Messenger::POST_MESSAGE_URL, captured_url
  end

  test 'upload_file defaults filename when attachment has none' do
    attachment = Struct.new(:attached?, :download, :filename, :content_type, keyword_init: true).new(
      attached?: true,
      download: 'bytes',
      filename: ActiveStorage::Filename.new(''),
      content_type: 'image/png'
    )
    captured = nil
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    messenger.stub(:post, lambda { |url, payload|
      captured = [url, payload] if url == Slack::Messenger::GET_UPLOAD_URL
      case url
      when Slack::Messenger::GET_UPLOAD_URL
        { 'ok' => true, 'upload_url' => 'https://files.slack.com/upload/v1/test', 'file_id' => 'F1' }
      when Slack::Messenger::COMPLETE_UPLOAD_URL
        { 'ok' => true }
      else
        { 'ok' => false }
      end
    }) do
      messenger.stub(:post_file_to_upload_url, nil) do
        messenger.send(:upload_file, user_id: 'U123', text: 'hi', attachment:)
      end
    end

    assert_equal({ filename: 'print-photo.jpg', length: 'bytes'.bytesize }, captured[1])
  end

  test 'post_file_to_upload_url raises on non-success response' do
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    failed_response = Net::HTTPServiceUnavailable.new('1.1', '503', 'Service Unavailable')
    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_req| failed_response }
    Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(fake_http) }) do
      error = assert_raises(Slack::Messenger::Error) do
        messenger.send(
          :post_file_to_upload_url,
          'https://files.slack.com/upload/v1/test',
          'data',
          content_type: 'image/jpeg'
        )
      end
      assert_match(/HTTP 503/, error.message)
    end
  end

  test 'dm_with_attachment uses files upload v2 flow' do
    attachment = Struct.new(:attached?, :download, :filename, :content_type, keyword_init: true).new(
      attached?: true,
      download: 'image-bytes',
      filename: ActiveStorage::Filename.new('final.jpg'),
      content_type: 'image/jpeg'
    )
    calls = []
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    messenger.stub(:post, lambda { |url, payload|
      calls << [url, payload]
      case url
      when Slack::Messenger::GET_UPLOAD_URL
        { 'ok' => true, 'upload_url' => 'https://files.slack.com/upload/v1/test', 'file_id' => 'F123' }
      when Slack::Messenger::COMPLETE_UPLOAD_URL
        { 'ok' => true }
      else
        { 'ok' => false, 'error' => 'unexpected_url' }
      end
    }) do
      messenger.stub(:post_file_to_upload_url, nil) do
        messenger.dm_with_attachment(user_id: 'U123', text: 'Your print is ready', attachment:)
      end
    end

    assert_equal Slack::Messenger::GET_UPLOAD_URL, calls[0][0]
    assert_equal({ filename: 'final.jpg', length: 'image-bytes'.bytesize }, calls[0][1])
    assert_equal Slack::Messenger::COMPLETE_UPLOAD_URL, calls[1][0]
    assert_equal(
      { channel_id: 'U123', initial_comment: 'Your print is ready', files: [{ id: 'F123', title: 'final.jpg' }] },
      calls[1][1]
    )
  end
end
