require 'net/http'
require 'json'

# POSTs a JSON notice to Setting.enforce_claims_webhook_url when a print is paused because it
# is unclaimed or its filament isn't allowed on its printer, continued once claimed, or
# cancelled for being continued unclaimed too many times.
# Filename and claimant are left out of private prints.
class ClaimEnforcementWebhook
  class Error < StandardError; end

  PAUSED = 'paused'.freeze
  CONTINUED = 'continued'.freeze
  CANCELLED = 'cancelled'.freeze
  ACTIONS = [PAUSED, CONTINUED, CANCELLED].freeze
  TIMEOUT = 10

  def self.deliver(job, action, reasons: nil, url: Setting.enforce_claims_webhook_url)
    new(job, action, reasons:, url:).deliver
  end

  # +reasons+: why, e.g. %w[unclaimed filament_not_allowed] or %w[claimed]. Defaults to the
  # claim reason, which is all notices queued before filament holds existed could mean.
  def initialize(job, action, url:, reasons: nil)
    raise ArgumentError, "unknown action #{action.inspect}" unless ACTIONS.include?(action)

    @job = job
    @action = action
    @reasons = Array(reasons).presence || [action == CONTINUED ? 'claimed' : 'unclaimed']
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
      reason: @reasons.first,
      reasons: @reasons,
      occurred_at: Time.current.iso8601,
      printer: { id: @job.printer_id, name: @job.printer.name },
      job: job_payload
    }
  end

  private

  def job_payload
    data = { id: @job.id, status: @job.status, private: @job.private?, url: job_url,
             filament_problem: @job.filament_hold_reason }
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
