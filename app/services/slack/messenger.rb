require 'net/http'
require 'json'
require 'securerandom'

module Slack
  class Messenger
    class Error < StandardError; end

    POST_MESSAGE_URL = 'https://slack.com/api/chat.postMessage'.freeze
    CONVERSATIONS_OPEN_URL = 'https://slack.com/api/conversations.open'.freeze
    GET_UPLOAD_URL = 'https://slack.com/api/files.getUploadURLExternal'.freeze
    COMPLETE_UPLOAD_URL = 'https://slack.com/api/files.completeUploadExternal'.freeze
    NOTIFICATION_PHOTO_FILENAME = 'final.jpg'.freeze
    NOTIFICATION_PHOTO_CONTENT_TYPE = 'image/jpeg'.freeze

    def self.dm(user_id:, text:)
      new.dm(user_id:, text:)
    end

    def self.dm_with_attachment(user_id:, text:, attachment: nil)
      new.dm_with_attachment(user_id:, text:, attachment:)
    end

    def initialize(token: SlackConfig.api_token)
      @token = token
    end

    def dm(user_id:, text:)
      raise Error, 'Slack API token is missing' if @token.blank?
      raise Error, 'Slack user ID is missing' if user_id.blank?

      response = post_json(POST_MESSAGE_URL, { channel: open_dm_channel(user_id), text: })
      assert_ok!(response, 'chat.postMessage')

      response
    end

    def dm_with_attachment(user_id:, text:, attachment: nil)
      if attachment&.attached?
        upload_file(user_id:, text:, attachment:)
      else
        dm(user_id:, text:)
      end
    end

    private

    def upload_file(user_id:, text:, attachment:)
      raise Error, 'Slack API token is missing' if @token.blank?

      file_data = attachment.download
      filename = NOTIFICATION_PHOTO_FILENAME
      content_type = NOTIFICATION_PHOTO_CONTENT_TYPE
      upload_info = request_upload_url(filename, file_data)
      deliver_uploaded_file(upload_info, file_data, filename:, content_type:)
      finalize_upload(user_id:, text:, upload_info:, filename:)
    end

    def request_upload_url(filename, file_data)
      upload_info = post_form(GET_UPLOAD_URL, { filename:, length: file_data.bytesize.to_s })
      assert_ok!(upload_info, 'files.getUploadURLExternal')
      upload_info
    end

    def deliver_uploaded_file(upload_info, file_data, filename:, content_type:)
      post_file_to_upload_url(
        upload_info.fetch('upload_url'),
        file_data,
        filename:,
        content_type:
      )
    end

    def finalize_upload(user_id:, text:, upload_info:, filename:)
      response = post_json(
        COMPLETE_UPLOAD_URL,
        channel_id: open_dm_channel(user_id),
        initial_comment: text,
        files: [{ id: upload_info.fetch('file_id'), title: filename }]
      )
      assert_ok!(response, 'files.completeUploadExternal')
      response
    end

    def open_dm_channel(user_id)
      response = post_json(CONVERSATIONS_OPEN_URL, { users: user_id })
      assert_ok!(response, 'conversations.open')

      channel_id = response.dig('channel', 'id')
      raise Error, 'Slack DM channel id missing' if channel_id.blank?

      channel_id
    end

    def post_file_to_upload_url(upload_url, file_data, filename:, content_type:)
      uri = URI(upload_url)
      boundary = "----RubySlackUpload#{SecureRandom.hex(16)}"
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
      request.body = build_filename_multipart(boundary, filename, file_data, content_type)

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(request) }
      return if response.is_a?(Net::HTTPSuccess)

      raise Error, "Slack file upload failed (HTTP #{response.code})"
    end

    def build_filename_multipart(boundary, filename, file_data, content_type)
      header = [
        "--#{boundary}\r\n",
        "Content-Disposition: form-data; name=\"filename\"; filename=\"#{filename}\"\r\n",
        "Content-Type: #{content_type.presence || 'application/octet-stream'}\r\n\r\n"
      ].join
      footer = "\r\n--#{boundary}--\r\n"

      header.b + file_data.b + footer.b
    end

    def post_json(url, payload)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@token}"
      request['Content-Type'] = 'application/json; charset=utf-8'
      request.body = payload.to_json

      execute(request, uri)
    end

    def post_form(url, payload)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@token}"
      request.set_form_data(payload.transform_keys(&:to_s).transform_values(&:to_s))

      execute(request, uri)
    end

    def execute(request, uri)
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
      JSON.parse(response.body)
    end

    def assert_ok!(response, step)
      return if response['ok']

      raise Error, api_error_message(response, step)
    end

    def api_error_message(response, step)
      parts = ["#{step}: #{response['error']}"]
      metadata_messages = response.dig('response_metadata', 'messages')
      parts.concat(metadata_messages) if metadata_messages.present?
      parts.join(' — ')
    end
  end
end
