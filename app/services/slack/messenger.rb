require 'net/http'
require 'json'

module Slack
  class Messenger
    class Error < StandardError; end

    POST_MESSAGE_URL = 'https://slack.com/api/chat.postMessage'.freeze
    CONVERSATIONS_OPEN_URL = 'https://slack.com/api/conversations.open'.freeze
    GET_UPLOAD_URL = 'https://slack.com/api/files.getUploadURLExternal'.freeze
    COMPLETE_UPLOAD_URL = 'https://slack.com/api/files.completeUploadExternal'.freeze

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

      response = post(POST_MESSAGE_URL, { channel: open_dm_channel(user_id), text: })
      raise Error, response['error'] || 'Unknown Slack error' unless response['ok']

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
      filename = attachment_filename(attachment)
      upload_info = post(GET_UPLOAD_URL, { filename:, length: file_data.bytesize })
      raise Error, upload_info['error'] || 'Unknown Slack error' unless upload_info['ok']

      post_file_to_upload_url(upload_info.fetch('upload_url'), file_data, content_type: attachment.content_type)
      response = post(
        COMPLETE_UPLOAD_URL,
        channel_id: open_dm_channel(user_id),
        initial_comment: text,
        files: [{ id: upload_info.fetch('file_id'), title: filename }]
      )
      raise Error, response['error'] || 'Unknown Slack error' unless response['ok']

      response
    end

    def open_dm_channel(user_id)
      response = post(CONVERSATIONS_OPEN_URL, { users: user_id })
      raise Error, response['error'] || 'Unknown Slack error' unless response['ok']

      channel_id = response.dig('channel', 'id')
      raise Error, 'Slack DM channel id missing' if channel_id.blank?

      channel_id
    end

    def attachment_filename(attachment)
      attachment.filename.to_s.presence || 'print-photo.jpg'
    end

    def post_file_to_upload_url(upload_url, file_data, content_type:)
      uri = URI(upload_url)
      request = Net::HTTP::Post.new(uri)
      request.body = file_data
      request['Content-Type'] = content_type.presence || 'application/octet-stream'

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(request) }
      return if response.is_a?(Net::HTTPSuccess)

      raise Error, "Slack file upload failed (HTTP #{response.code})"
    end

    def post(url, payload)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@token}"
      request['Content-Type'] = 'application/json; charset=utf-8'
      request.body = payload.to_json

      execute(request, uri)
    end

    def execute(request, uri)
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
      JSON.parse(response.body)
    end
  end
end
