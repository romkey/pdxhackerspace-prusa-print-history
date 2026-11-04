module PrusaConnect
  # Builds a human-readable explanation of why a printer errored or needs attention from what
  # Prusa Connect knows: the printer's state reason, the latest failed job, and recent
  # notifications for that printer. Returns nil when Connect has nothing to add.
  class ErrorDetail
    Result = Struct.new(:message, :raw, keyword_init: true)

    NOTIFICATION_WINDOW = 30.minutes
    FAILED_STATES = %w[FIN_ERROR FIN_STOPPED].freeze

    def self.fetch(printer, since:, client: ApiClient.new)
      new(printer, since: since, client: client).fetch
    end

    def initialize(printer, since:, client:)
      @printer = printer
      @since = since
      @client = client
    end

    def fetch
      uuid = @printer.prusa_connect_uuid
      return nil if uuid.blank? || !@client.configured?

      state = @client.printer(uuid)
      job = failed_job(uuid)
      notes = notifications_for(uuid)
      lines = [state_line(state), job_line(job), *notes.pluck('text')].compact_blank.uniq
      return nil if lines.empty?

      Result.new(message: lines.join(' — '), raw: { printer: state.slice('printer_state', 'state_reason'),
                                                    job: job, notifications: notes })
    end

    private

    def state_line(state)
      return nil unless %w[ERROR ATTENTION].include?(state['printer_state'] || state['state'])

      state['state_reason'].presence
    end

    def failed_job(uuid)
      @client.jobs(uuid).find { |job| FAILED_STATES.include?(job['state']) && recent?(job['end']) }
    end

    def job_line(job)
      return nil if job.nil?

      tags = Array(job.dig('reason', 'tag')).reject { |tag| tag == 'IGNORED' }
      note = job.dig('reason', 'other').presence
      text = [*tags.map { |tag| tag.humanize.downcase }, note].compact.join(', ')
      text.presence && "Marked in Connect: #{text}"
    end

    def notifications_for(uuid)
      @client.notifications.select do |note|
        note.dig('data', 'printer_uuid') == uuid && recent?(note['created']) && note['text'].present?
      end
    end

    def recent?(unix)
      return false if unix.blank?

      Time.zone.at(unix) >= @since - NOTIFICATION_WINDOW
    end
  end
end
