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

    def rtsps
      @runner.run(ffmpeg_argv, timeout: 8, binary: true)
    end

    def ffmpeg_argv
      ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-rtsp_transport', 'tcp', '-timeout', '5000000',
       '-tls_verify', '0', '-i', stream_url, '-frames:v', '1', '-f', 'image2', '-vcodec', 'mjpeg', 'pipe:1']
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
