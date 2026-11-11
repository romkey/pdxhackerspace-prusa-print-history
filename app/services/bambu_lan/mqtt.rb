require 'json'

module BambuLan
  # Short MQTT-over-TLS session. LAN mode must be on to connect; Developer
  # Mode must also be on or the printer accepts reads and drops commands.
  class Mqtt
    PORT = 8883
    REPORT_WAIT = 8
    COMMAND_WAIT = 8

    def initialize(printer, session: nil)
      @printer = printer
      @session = session
    end

    def fetch_report
      with_session do |session|
        session.subscribe(report_topic)
        session.publish(request_topic, JSON.generate(pushall))
        read_snapshot(session)
      end
    end

    def command(category, name, extra = {})
      with_session do |session|
        seq = next_sequence
        session.subscribe(report_topic)
        session.publish(request_topic, JSON.generate(envelope(category, name, seq, extra)))
        ack = read_ack(session, category, seq)
        raise Error, ack_failure(ack) unless ack['result'].to_s == 'success'

        true
      end
    end

    private

    def with_session
      if @session
        yield @session
      else
        session = MqttSession.open(@printer)
        begin
          yield session
        ensure
          session.disconnect
        end
      end
    end

    def read_snapshot(session)
      best = nil
      each_message(session, REPORT_WAIT) do |message|
        return message if ReportSelector.snapshot?(message)

        best = ReportSelector.better(best, message)
      end
      return best if best

      raise Error, 'No status report from the printer. Check the IP, serial, access code, and that LAN mode is on.'
    end

    def read_ack(session, category, seq)
      each_message(session, COMMAND_WAIT) do |message|
        node = message[category]
        return node if node.is_a?(Hash) && node['sequence_id'].to_s == seq && node['result'].present?
      end
      raise Error, 'The printer did not accept the command. LAN mode and Developer Mode both have to be on.'
    end

    def each_message(session, seconds)
      deadline = mono + seconds
      while (payload = session.next_payload(deadline))
        message = parse(payload)
        yield message if message
      end
    end

    def parse(payload)
      JSON.parse(payload.to_s)
    rescue JSON::ParserError
      nil
    end

    def pushall
      { 'pushing' => { 'sequence_id' => next_sequence, 'command' => 'pushall' } }
    end

    def envelope(category, name, seq, extra)
      { category => extra.merge('sequence_id' => seq, 'command' => name) }
    end

    def next_sequence
      @sequence = @sequence.to_i + 1
      @sequence.to_s
    end

    def report_topic
      "device/#{serial}/report"
    end

    def request_topic
      "device/#{serial}/request"
    end

    def serial
      @printer.bambu_serial.to_s.strip
    end

    def ack_failure(ack)
      ack['reason'].to_s.presence || 'The printer rejected the command.'
    end

    def mono
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
