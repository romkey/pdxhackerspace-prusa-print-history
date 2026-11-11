require 'open3'

module BambuLan
  # Runs a command without a shell and kills it if it outlives the timeout.
  class ProcessRunner
    def run(argv, timeout:, binary: true)
      Open3.popen3(*argv) { |stdin, stdout, stderr, wait| capture([stdin, stdout, stderr], wait, timeout, binary) }
    end

    private

    def capture(streams, wait, timeout, binary)
      stdin, stdout, stderr = streams
      stdin.close
      stdout.binmode if binary
      output = Thread.new { stdout.read }
      error = Thread.new { stderr.read }
      finished = wait.join(timeout)
      reap(wait) unless finished
      body = output.value.to_s
      detail = error.value.to_s.strip.byteslice(0, 500)
      raise Error, 'timed out' unless finished
      raise Error, detail.presence || "command failed (#{wait.value.exitstatus})" unless wait.value.success?

      body
    end

    def reap(wait)
      Process.kill('KILL', wait.pid)
      wait.join(2)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end
  end
end
