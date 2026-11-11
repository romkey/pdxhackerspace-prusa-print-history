require 'openssl'
require 'socket'

module BambuLan
  # A1 / P1 chamber camera: TLS on port 6000, an 80-byte auth packet, then
  # 16-byte headers followed by a JPEG.
  class JpegCamera
    PORT = 6000
    HEADER = 16
    MAX_FRAME = 2_000_000

    def self.auth_packet(username:, access_code:)
      packet = String.new(encoding: Encoding::BINARY)
      packet << [0x40, 0x3000, 0, 0].pack('V4')
      packet << username.to_s.b.ljust(32, "\0".b).byteslice(0, 32)
      packet << access_code.to_s.b.ljust(32, "\0".b).byteslice(0, 32)
      packet
    end

    def self.extract_frame(buffer)
      return nil if buffer.bytesize < HEADER

      size = buffer.unpack1('V')
      return nil if size <= 0 || size > MAX_FRAME
      return nil if buffer.bytesize < HEADER + size

      [buffer.byteslice(HEADER, size), buffer.byteslice((HEADER + size)..)]
    end

    def initialize(printer)
      @printer = printer
    end

    def snapshot
      socket = open_socket
      socket.write(self.class.auth_packet(username: 'bblp', access_code: @printer.bambu_access_code.to_s))
      read_frame(socket)
    ensure
      socket&.close
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
      raise Error, "camera connection failed: #{e.class}"
    end

    def ssl_context
      context = OpenSSL::SSL::SSLContext.new
      context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      context.verify_hostname = false if context.respond_to?(:verify_hostname=)
      context
    end

    def read_frame(socket)
      buffer = +''.b
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
        socket.timeout = 5 if socket.respond_to?(:timeout=)
        buffer << socket.readpartial(4096)
        frame, = self.class.extract_frame(buffer)
        return frame if frame&.start_with?("\xFF\xD8".b)
      end
      raise Error, 'camera timed out'
    rescue IOError => e
      raise Error, "camera read failed: #{e.class}"
    end
  end
end
