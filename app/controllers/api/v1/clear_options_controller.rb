module Api
  module V1
    # The choices a clearing form needs, so clients never hardcode them.
    class ClearOptionsController < BaseController
      allow_device_tokens :show
      allow_kiosk_sessions :show

      def show
        render json: {
          outcomes: Job::CLEAR_OUTCOMES,
          failure_reasons: Job::CLEAR_FAILURE_REASONS.map { |value, label| { value:, label: } },
          detail_required_for: %w[other],
          label_printers: LabelPrinter.ordered.map do |printer|
            { id: printer.id, name: printer.name, default: printer.default_printer? }
          end
        }
      end
    end
  end
end
