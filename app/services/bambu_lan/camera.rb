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
      when :rtsps then attempt { rtsps }
      when :jpeg then attempt { @jpeg.snapshot }
      else attempt { rtsps } || attempt { @jpeg.snapshot }
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
        @runner.run(ffmpeg_argv(path), timeout: 12, binary: true)
      rescue Error => e
        failure = e
      end
      bytes = File.binread(path)
      return bytes if bytes.b.start_with?("\xFF\xD8".b)

      raise failure || Error.new('camera returned no frame')
    ensure
      FileUtils.rm_f(path) if path
    end

    def ffmpeg_argv(path)
      ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-rtsp_transport', 'tcp', '-timeout', '8000000',
       '-tls_verify', '0', '-i', stream_url, '-an', '-frames:v', '1', '-q:v', '5', '-y', path]
    end

    def stream_url
      "rtsps://bblp:#{@printer.bambu_access_code}@#{Host.for(@printer)}:322/streaming/live/1"
    end

    def attempt
      yield
    rescue Error => e
      Rails.logger.warn("[BambuLan] camera failed for printer ##{@printer.id}: #{scrub(e.message)}")
      nil
    end

    def scrub(message)
      Secrets.scrub(message, @printer.bambu_access_code)
    end
  end
end
