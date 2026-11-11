require 'fileutils'
require 'tempfile'

module BambuLan
  class Camera
    def initialize(printer, runner: ProcessRunner.new, jpeg: nil)
      @printer = printer
      @runner = runner
      @jpeg = jpeg || JpegCamera.new(printer)
    end

    def snapshot
      case Models.camera(@printer.model)
      when :rtsps then attempt('RTSPS') { rtsps }
      when :jpeg then attempt('JPEG') { @jpeg.snapshot }
      else attempt('RTSPS') { rtsps } || attempt('JPEG') { @jpeg.snapshot }
      end
    end

    private

    # ffmpeg often writes the JPEG and then blocks on the RTSP socket, so a
    # timeout still counts when the file starts with a JPEG marker.
    def rtsps
      file = Tempfile.create(['bambu-camera', '.jpg'])
      path = file.path
      file.close
      failure = nil
      begin
        @runner.run(ffmpeg_argv(path), timeout: 20, binary: true)
      rescue Error => e
        failure = e
      end
      bytes = File.binread(path)
      if bytes.b.start_with?("\xFF\xD8".b)
        Rails.logger.info("Photo capture #{@printer.name}: RTSPS frame #{bytes.bytesize} bytes")
        return bytes
      end

      detail = failure&.message || 'ffmpeg wrote nothing'
      raise Error, "no JPEG from RTSPS (#{detail})"
    ensure
      FileUtils.rm_f(path) if path
    end

    # Default ffmpeg probing waits for about 5 MB. The P2S stream is ~1 Mbps,
    # so that is longer than the capture timeout and the process is killed
    # before a frame is written, with an empty error log.
    def ffmpeg_argv(path)
      ['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-rtsp_transport', 'tcp', '-timeout', '8000000',
       '-tls_verify', '0', '-analyzeduration', '500000', '-probesize', '65536', '-i', stream_url,
       '-an', '-frames:v', '1', '-q:v', '5', '-y', path]
    end

    def stream_url
      "rtsps://bblp:#{@printer.bambu_access_code}@#{Host.for(@printer)}:322/streaming/live/1"
    end

    def attempt(transport)
      yield
    rescue Error => e
      Rails.logger.info(
        "Photo capture #{@printer.name}: #{transport} failed " \
        "(#{@printer.model}, #{Host.for(@printer)}): #{scrub(e.message)}"
      )
      nil
    end

    def scrub(message)
      Secrets.scrub(message, @printer.bambu_access_code)
    end
  end
end
