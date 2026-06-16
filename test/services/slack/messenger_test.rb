require 'test_helper'

class SlackMessengerTest < ActiveSupport::TestCase
  DM_CHANNEL_ID = 'D069C7QFK'.freeze

  test 'dm raises when token missing' do
    ENV.delete('SLACK_API_TOKEN')
    assert_raises(Slack::Messenger::Error) do
      Slack::Messenger.new(token: nil).dm(user_id: 'U123', text: 'hello')
    end
  end

  test 'dm posts to chat.postMessage with dm channel id' do
    captured = nil
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    messenger.stub(:open_dm_channel, DM_CHANNEL_ID) do
      messenger.stub(:post_json, lambda { |_url, payload|
        captured = payload
        { 'ok' => true }
      }) do
        messenger.dm(user_id: 'U123', text: 'Your print is ready')
      end
    end

    assert_equal DM_CHANNEL_ID, captured[:channel]
    assert_equal 'Your print is ready', captured[:text]
  end

  test 'open_dm_channel calls conversations.open' do
    captured = nil
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    messenger.stub(:post_json, lambda { |url, payload|
      captured = [url, payload]
      { 'ok' => true, 'channel' => { 'id' => DM_CHANNEL_ID } }
    }) do
      channel_id = messenger.send(:open_dm_channel, 'U123')

      assert_equal DM_CHANNEL_ID, channel_id
    end

    assert_equal Slack::Messenger::CONVERSATIONS_OPEN_URL, captured[0]
    assert_equal({ users: 'U123' }, captured[1])
  end

  test 'dm raises on slack api error with response metadata' do
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    messenger.stub(:open_dm_channel, DM_CHANNEL_ID) do
      api_error = {
        'ok' => false,
        'error' => 'invalid_arguments',
        'response_metadata' => { 'messages' => ['[ERROR] bad channel [json-pointer:/channel]'] }
      }
      messenger.stub(:post_json, api_error) do
        error = assert_raises(Slack::Messenger::Error) do
          messenger.dm(user_id: 'U404', text: 'hi')
        end
        assert_match(/chat\.postMessage: invalid_arguments/, error.message)
        assert_match(/bad channel/, error.message)
      end
    end
  end

  test 'open_dm_channel raises when response omits channel id' do
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    messenger.stub(:post_json, { 'ok' => true, 'channel' => {} }) do
      error = assert_raises(Slack::Messenger::Error) do
        messenger.send(:open_dm_channel, 'U123')
      end
      assert_equal 'Slack DM channel id missing', error.message
    end
  end

  test 'open_dm_channel raises on conversations.open api error' do
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    messenger.stub(:post_json, { 'ok' => false, 'error' => 'missing_scope' }) do
      error = assert_raises(Slack::Messenger::Error) do
        messenger.send(:open_dm_channel, 'U123')
      end
      assert_match(/conversations\.open: missing_scope/, error.message)
    end
  end

  test 'dm_with_attachment without attachment uses chat.postMessage' do
    captured_url = nil
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    messenger.stub(:open_dm_channel, DM_CHANNEL_ID) do
      messenger.stub(:post_json, lambda { |url, _payload|
        captured_url = url
        { 'ok' => true }
      }) do
        messenger.dm_with_attachment(user_id: 'U123', text: 'Text only', attachment: nil)
      end
    end

    assert_equal Slack::Messenger::POST_MESSAGE_URL, captured_url
  end

  test 'request_upload_url uses form encoding' do
    captured_request = nil
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    messenger.stub(:execute, lambda { |request, _uri|
      captured_request = request
      { 'ok' => true, 'upload_url' => 'https://files.slack.com/upload/v1/test', 'file_id' => 'F1' }
    }) do
      messenger.send(:post_form, Slack::Messenger::GET_UPLOAD_URL, { filename: 'photo.jpg', length: '42' })
    end

    assert_equal 'application/x-www-form-urlencoded', captured_request.content_type
    assert_includes captured_request.body, 'filename=photo.jpg'
    assert_includes captured_request.body, 'length=42'
  end

  test 'upload_file always uses final.jpg and image/jpeg for notification photos' do
    attachment = Struct.new(:attached?, :download, :filename, :content_type, keyword_init: true).new(
      attached?: true,
      download: 'bytes',
      filename: ActiveStorage::Filename.new('SET_OF~1.BGC'),
      content_type: 'application/octet-stream'
    )
    form_payload = nil
    upload_args = nil
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    messenger.stub(:post_form, lambda { |url, payload|
      form_payload = payload if url == Slack::Messenger::GET_UPLOAD_URL
      { 'ok' => true, 'upload_url' => 'https://files.slack.com/upload/v1/test', 'file_id' => 'F1' }
    }) do
      messenger.stub(:post_json, { 'ok' => true }) do
        messenger.stub(:open_dm_channel, DM_CHANNEL_ID) do
          messenger.stub(:post_file_to_upload_url, lambda { |*_args, **kwargs|
            upload_args = kwargs
            nil
          }) do
            messenger.send(:upload_file, user_id: 'U123', text: 'hi', attachment:)
          end
        end
      end
    end

    assert_equal({ filename: 'final.jpg', length: 'bytes'.bytesize.to_s }, form_payload)
    assert_equal 'final.jpg', upload_args[:filename]
    assert_equal 'image/jpeg', upload_args[:content_type]
  end

  test 'post_file_to_upload_url sends multipart filename field' do
    captured_request = nil
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    fake_http = Object.new
    fake_http.define_singleton_method(:request) do |request|
      captured_request = request
      Net::HTTPOK.new('1.1', '200', 'OK')
    end
    Net::HTTP.stub(:start, ->(*_args, **_kwargs, &block) { block.call(fake_http) }) do
      messenger.send(
        :post_file_to_upload_url,
        'https://files.slack.com/upload/v1/test',
        'binary-data',
        filename: 'final.jpg',
        content_type: 'image/jpeg'
      )
    end

    assert_match(%r{multipart/form-data}, captured_request['Content-Type'])
    assert_includes captured_request.body, 'name="filename"'
    assert_includes captured_request.body, 'final.jpg'
    assert_includes captured_request.body, 'Content-Type: image/jpeg'
  end

  test 'build_filename_multipart defaults missing content type to octet-stream' do
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    body = messenger.send(:build_filename_multipart, 'boundary', 'final.jpg', 'data', nil)

    assert_includes body, 'Content-Type: application/octet-stream'
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
          filename: 'photo.jpg',
          content_type: 'image/jpeg'
        )
      end
      assert_match(/HTTP 503/, error.message)
    end
  end

  test 'dm_with_attachment uses files upload v2 flow with normalized photo metadata' do
    attachment = Struct.new(:attached?, :download, :filename, :content_type, keyword_init: true).new(
      attached?: true,
      download: 'image-bytes',
      filename: ActiveStorage::Filename.new('SET_OF~1.BGC'),
      content_type: 'application/octet-stream'
    )
    form_calls = []
    json_calls = []
    messenger = Slack::Messenger.new(token: 'xoxb-test')
    messenger.stub(:post_form, lambda { |url, payload|
      form_calls << [url, payload]
      { 'ok' => true, 'upload_url' => 'https://files.slack.com/upload/v1/test', 'file_id' => 'F123' }
    }) do
      messenger.stub(:post_json, lambda { |url, payload|
        json_calls << [url, payload]
        case url
        when Slack::Messenger::CONVERSATIONS_OPEN_URL
          { 'ok' => true, 'channel' => { 'id' => DM_CHANNEL_ID } }
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
    end

    assert_equal Slack::Messenger::GET_UPLOAD_URL, form_calls[0][0]
    assert_equal({ filename: 'final.jpg', length: 'image-bytes'.bytesize.to_s }, form_calls[0][1])
    assert_equal Slack::Messenger::CONVERSATIONS_OPEN_URL, json_calls[0][0]
    assert_equal Slack::Messenger::COMPLETE_UPLOAD_URL, json_calls[1][0]
    complete_payload = {
      channel_id: DM_CHANNEL_ID,
      initial_comment: 'Your print is ready',
      files: [{ id: 'F123', title: 'final.jpg' }]
    }

    assert_equal complete_payload, json_calls[1][1]
  end
end
