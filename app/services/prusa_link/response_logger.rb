module PrusaLink
  module ResponseLogger
    module_function

    def log_json!(printer:, path:, payload:)
      label = "PrusaLink printer ##{printer.id} (#{printer.name}) GET #{path}"
      body = payload.nil? ? '(empty)' : JSON.pretty_generate(payload)

      Rails.logger.info("[PrusaLink JSON] #{label}\n#{body}")
    end

    def log_binary!(printer:, path:, byte_size:)
      Rails.logger.info(
        "[PrusaLink binary] printer ##{printer.id} (#{printer.name}) GET #{path} — #{byte_size || 0} bytes"
      )
    end
  end
end
