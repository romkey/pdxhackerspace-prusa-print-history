require 'json'
require 'openssl'
require 'socket'

module BambuLan
  # Bambu Studio's print preview. The printer keeps the current plate image in
  # RAM at mem:/26 and serves it on TLS port 6000. That image is available on a
  # P2S while the sliced project itself stays on internal storage FTPS cannot read.
  class MemPreview
    PORT = 6000
    PATH = 'mem:/26'.freeze
    HEADER = 16
    MAGIC_LOGIN = 0x0101013f
    MAGIC_CTRL = 0x0102013f

    def self.fetch(printer)
      new(printer).jpeg
    end

    def initialize(printer, socket: nil)
      @printer = printer
      @socket = socket
    end

    def jpeg
      owned = @socket.nil?
      socket = @socket || open_socket
      Session.new(socket, code: @printer.bambu_access_code).preview
    ensure
      socket&.close if owned
    end

    class Session
      def initialize(socket, code: nil, path: PATH)
        @socket = socket
        @code = code
        @path = path
        @buffer = +''.b
      end

      def preview
        login
        setup
        download
      end

      def login
        user = 'bblp'.b.ljust(8, "\0")
        code = @code.to_s.b.byteslice(0, 8).ljust(8, "\0")
        write_frame(MAGIC_LOGIN, user + code, sequence: 1)
        read_frame
      end

      def setup
        body = JSON.generate(
          'sequence' => 0, 'mtype' => 12_291,
          'req' => { 't_av' => 0, 'mtype' => 12_289, 'peer_t' => 3, 'pid' => '', 'ver' => '' }
        )
        write_frame(MAGIC_CTRL, body, sequence: 2)
        read_frame
      end

      def download
        blob = JSON.generate(
          'command' => 'get_project_file', 'file_rel_path' => '',
          'peer_host' => 'studio', 'sequence_id' => 3, 'version' => 1
        )
        request = JSON.generate(
          'mtype' => 12_289, 'cmdtype' => 4, 'sequence' => 3,
          'req' => { 'mem_dl_param_size' => blob.bytesize, 'offset' => 0, 'path' => @path }
        )
        write_frame(MAGIC_CTRL, "#{request}\n\n#{blob}", sequence: 3)
        collect
      end

      private

      def collect
        image = +''.b
        20.times do
          parsed, binary = split(read_frame)
          image << fragment(parsed, binary)
          return image if parsed['result'].to_i.zero?

          refuse!(parsed['result']) unless parsed['result'].to_i == 1
        end
        raise Error, 'preview incomplete'
      end

      def fragment(parsed, binary)
        reply = parsed['reply'].is_a?(Hash) ? parsed['reply'] : {}
        return ''.b if reply['size'].to_i.zero? && reply.key?('mem_dl_param_size')

        binary
      end

      def refuse!(result)
        raise Error, "preview unavailable (#{result})"
      end

      def split(payload)
        json, binary = payload.split("\n\n", 2)
        [JSON.parse(json.to_s), binary.to_s.b]
      rescue JSON::ParserError
        raise Error, 'preview reply was not JSON'
      end

      def write_frame(magic, payload, sequence:)
        @socket.write([payload.bytesize, magic, sequence, 0].pack('V4') + payload.b)
      end

      def read_frame
        header = read_exact(HEADER)
        length, = header.unpack('V4')
        raise Error, 'preview frame too large' if length > 300_000

        length.positive? ? read_exact(length) : ''.b
      end

      def read_exact(count)
        while @buffer.bytesize < count
          chunk = @socket.readpartial(count - @buffer.bytesize)
          raise Error, 'preview closed' if chunk.blank?

          @buffer << chunk
        end
        @buffer.slice!(0, count)
      rescue IOError, SystemCallError => e
        raise Error, "preview read failed: #{e.class}"
      end
    end

    private

    def open_socket
      tcp = Socket.tcp(Host.for(@printer), PORT, connect_timeout: 5)
      ssl = OpenSSL::SSL::SSLSocket.new(tcp, ssl_context)
      ssl.hostname = Host.for(@printer) if ssl.respond_to?(:hostname=)
      ssl.sync_close = true
      ssl.connect
      ssl
    rescue SystemCallError, IO::TimeoutError, OpenSSL::SSL::SSLError => e
      raise Error, "preview connection failed: #{e.class}"
    end

    def ssl_context
      context = OpenSSL::SSL::SSLContext.new
      context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      context.verify_hostname = false if context.respond_to?(:verify_hostname=)
      context
    end
  end
end
