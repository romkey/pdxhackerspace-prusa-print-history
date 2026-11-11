require 'mqtt'
require 'securerandom'

module BambuLan
  # One MQTT-over-TLS connection. `next_payload` returns nil when the deadline passes.
  class MqttSession
    def self.open(printer)
      client = build(printer)
      client.connect
      new(client)
    rescue MQTT::Exception, SystemCallError, IO::TimeoutError, OpenSSL::SSL::SSLError, Timeout::Error => e
      raise Error, connection_failure(printer, e)
    end

    def self.build(printer)
      client = MQTT::Client.new(client_options(printer))
      client.ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      client.ssl_context.verify_hostname = false if client.ssl_context.respond_to?(:verify_hostname=)
      client
    end

    def self.client_options(printer)
      {
        host: Host.for(printer), port: Mqtt::PORT, ssl: true, verify_host: false,
        username: 'bblp', password: printer.bambu_access_code,
        client_id: "pph-#{SecureRandom.hex(6)}", keep_alive: 15, connect_timeout: 5, ack_timeout: 5
      }
    end

    def self.connection_failure(printer, error)
      "Bambu LAN connection failed: #{Secrets.scrub(error.message, printer.bambu_access_code)}"
    end

    def initialize(client)
      @client = client
    end

    delegate :subscribe, :publish, to: :@client

    def next_payload(deadline)
      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return nil if remaining <= 0

      packet = @client.instance_variable_get(:@read_queue).pop(timeout: remaining)
      packet&.payload
    end

    def disconnect
      @client&.disconnect
    rescue MQTT::Exception, IOError, SystemCallError
      nil
    end
  end
end
