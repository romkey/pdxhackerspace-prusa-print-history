require 'net/http'
require 'json'

module Slack
  class Messenger
    class Error < StandardError; end

    POST_MESSAGE_URL = 'https://slack.com/api/chat.postMessage'.freeze

    def self.dm(handle:, text:)
      new.dm(handle:, text:)
    end

    def initialize(token: ENV.fetch('SLACK_API_TOKEN', nil))
      @token = token
    end

    def dm(handle:, text:)
      raise Error, 'Slack API token is missing' if @token.blank?

      channel = handle.start_with?('@') ? handle : "@#{handle}"
      payload = { channel:, text:, as_user: true }
      response = post(payload)
      raise Error, response['error'] || 'Unknown Slack error' unless response['ok']

      response
    end

    private

    def post(payload)
      uri = URI(POST_MESSAGE_URL)
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@token}"
      request['Content-Type'] = 'application/json; charset=utf-8'
      request.body = payload.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
      JSON.parse(response.body)
    end
  end
end
