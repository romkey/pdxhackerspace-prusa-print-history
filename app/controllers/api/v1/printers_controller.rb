module Api
  module V1
    class PrintersController < BaseController
      def index
        printers = Printer.ordered.to_a
        jobs = ActionableJobs.by_printer(printers)
        printers = printers.select { |printer| jobs[printer.id] } if truthy?(params[:active])

        render json: {
          printers: printers.map { |printer| Json.printer(printer, job: jobs[printer.id], policy: access_policy) }
        }
      end

      def show
        printer = Printer.find(params.expect(:id))
        job = ActionableJobs.by_printer([printer])[printer.id]

        render json: { printer: Json.printer(printer, job:, policy: access_policy) }
      end

      private

      def truthy?(value)
        ActiveModel::Type::Boolean.new.cast(value).present?
      end
    end
  end
end
