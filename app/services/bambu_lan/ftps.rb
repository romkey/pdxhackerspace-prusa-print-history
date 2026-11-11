require 'fileutils'
require 'tempfile'

module BambuLan
  # Implicit FTPS on port 990. curl owns the TLS session reuse Bambu's
  # server requires on the data connection. The access code stays in a
  # mode-0600 config file, not in the process arguments.
  class Ftps
    def initialize(printer, runner: ProcessRunner.new)
      @printer = printer
      @runner = runner
      @owned = []
    end

    def download(remote_path)
      body = execute(config_body(30), '--output', '-', remote_url(remote_path), timeout: 35)
      raise Error, 'The printer returned an empty file.' if body.blank?

      body
    end

    def upload(io, remote_path)
      local = spill(io)
      config = "#{config_body(180)}\nupload-file = \"#{local}\""
      execute(config, remote_url(remote_path), timeout: 190)
      true
    ensure
      cleanup_spill
    end

    private

    def execute(config, *argv, timeout:)
      file = Tempfile.create(['bambu-ftps', '.conf'])
      file.chmod(0o600)
      file.write(config)
      file.flush
      @runner.run(['curl', '--config', file.path, *argv], timeout: timeout, binary: true)
    rescue Error => e
      raise Error, Secrets.scrub(e.message, password)
    ensure
      file&.close
      File.unlink(file.path) if file && File.exist?(file.path)
    end

    def config_body(max_time)
      <<~CONFIG
        user = "bblp:#{password}"
        insecure
        ssl-reqd
        silent
        show-error
        fail
        globoff
        connect-timeout = 5
        max-time = #{max_time.to_i}
      CONFIG
    end

    def remote_url(path)
      parts = normalize(path).split('/').map { |segment| ERB::Util.url_encode(segment) }
      "ftps://#{host}:990/#{parts.join('/')}"
    end

    def normalize(path)
      cleaned = path.to_s.strip.sub(%r{\Aftp://}i, '').sub(%r{\A/+}, '')
      raise Error, 'invalid printer path' if cleaned.blank? || cleaned.split('/').include?('..')

      cleaned
    end

    def spill(io)
      return io.path if io.respond_to?(:path) && io.path.present? && File.file?(io.path)

      temp = Tempfile.create(['bambu-upload', '.3mf'])
      temp.binmode
      io.rewind if io.respond_to?(:rewind)
      IO.copy_stream(io, temp)
      temp.flush
      @owned << temp
      temp.path
    end

    def cleanup_spill
      @owned.each do |temp|
        temp.close
        FileUtils.rm_f(temp.path)
      end
      @owned.clear
    end

    def host
      Host.for(@printer)
    end

    def password
      @printer.bambu_access_code.to_s
    end
  end
end
