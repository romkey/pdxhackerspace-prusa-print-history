require 'net/http'
require 'json'

# POSTs a JSON notice to Setting.enforce_claims_webhook_url when claim enforcement pauses or
# continues a print. Filename and claimant are left out of private prints.
class ClaimEnforcementWebhook
  class Error < StandardError; end

  PAUSED = 'paused'.freeze
  CONTINUED = 'continued'.freeze
  ACTIONS = [PAUSED, CONTINUED].freeze
  TIMEOUT = 10

  def self.deliver(job, action, url: Setting.enforce_claims_webhook_url)
    new(job, action, url:).deliver
  end

  def initialize(job, action, url:)
    raise ArgumentError, "unknown action #{action.inspect}" unless ACTIONS.include?(action)

    @job = job
    @action = action
    @url = url
  end

  # Returns false when no webhook is configured; raises Error when the endpoint fails.
  def deliver
    return false if @url.blank?

    response = post(URI.parse(@url), payload.to_json)
    raise Error, "webhook returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    true
  rescue URI::InvalidURIError, SocketError, SystemCallError, Timeout::Error, IOError, OpenSSL::SSL::SSLError => e
    raise Error, "webhook request failed: #{e.message}"
  end

  def payload
    {
      event: "print_#{@action}",
      reason: @action == PAUSED ? 'unclaimed' : 'claimed',
      occurred_at: Time.current.iso8601,
      printer: { id: @job.printer_id, name: @job.printer.name },
      job: job_payload
    }
  end

  private

  def job_payload
    data = { id: @job.id, status: @job.status, private: @job.private?, url: job_url }
    return data if @job.private?

    data.merge(filename: @job.filename, claimed_by: @job.owner&.display_name)
  end

  def job_url
    Rails.application.routes.url_helpers.job_url(@job, **AppUrl.options)
  end

  def post(uri, body)
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https',
                                            open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = body
      http.request(request)
    end
  end
end
