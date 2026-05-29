require 'net/http'
require 'json'

module Slack
  class Messenger
    class Error < StandardError; end

    POST_MESSAGE_URL = 'https://slack.com/api/chat.postMessage'.freeze
    FILES_UPLOAD_URL = 'https://slack.com/api/files.upload'.freeze

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

      response = post(POST_MESSAGE_URL, { channel: user_id, text:, as_user: true })
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

      boundary = "----RubyMultipartPost#{SecureRandom.hex(16)}"
      body = build_multipart_body(boundary, user_id:, text:, attachment:)
      response = post_multipart(FILES_UPLOAD_URL, body, boundary)
      raise Error, response['error'] || 'Unknown Slack error' unless response['ok']

      response
    end

    def build_multipart_body(boundary, user_id:, text:, attachment:)
      parts = []
      parts << multipart_field(boundary, 'channels', user_id)
      parts << multipart_field(boundary, 'initial_comment', text)
      parts << multipart_file(boundary, 'file', attachment)
      parts << "--#{boundary}--\r\n"
      parts.join
    end

    def multipart_field(boundary, name, value)
      "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"\r\n\r\n#{value}\r\n"
    end

    def multipart_file(boundary, name, attachment)
      filename = attachment.filename.to_s
      content_type = attachment.content_type || 'application/octet-stream'
      "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"; filename=\"#{filename}\"\r\n" \
        "Content-Type: #{content_type}\r\n\r\n#{attachment.download}\r\n"
    end

    def post(url, payload)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@token}"
      request['Content-Type'] = 'application/json; charset=utf-8'
      request.body = payload.to_json

      execute(request, uri)
    end

    def post_multipart(url, body, boundary)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@token}"
      request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
      request.body = body

      execute(request, uri)
    end

    def execute(request, uri)
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
      JSON.parse(response.body)
    end
  end
end
