module Api
  module V1
    # Sends the token's owner a single-use sign-in link. The link always goes to the owner;
    # these endpoints take no email address, so they cannot be used to mail anyone else.
    class LoginLinksController < BaseController
      def create
        issue(return_to: LoginLink.safe_return_to(params[:return_to].presence || '/'), purpose: 'sign_in')
      end

      # A sign-in link that lands on the problem report form for one printer.
      def create_problem_report
        printer = Printer.find(params.require(:printer_id))
        issue(return_to: Rails.application.routes.url_helpers.new_problem_report_path(printer_id: printer.id),
              purpose: 'problem_report')
      end

      private

      def issue(return_to:, purpose:)
        result = LoginLinkIssuer.call(user: current_user, return_to:, purpose:, delivery: params[:delivery],
                                      token: current_token, display_allowed: display_allowed?)
        audit!('login_link.requested', subject: current_user,
                                       detail: { purpose:, delivery: result.link.delivery, return_to: })
        render json: link_response(result), status: :accepted
      rescue LoginLinkIssuer::Error => e
        render_error(e.status, e.code, e.message)
      end

      def display_allowed?
        false
      end

      def link_response(result)
        json = { delivery: result.link.delivery, expires_at: Json.time(result.link.expires_at) }
        json[:sent_to] = masked_email(current_user.email) if result.link.delivery == 'email'
        json[:url] = result.url if result.link.delivery == 'display'
        json
      end

      def masked_email(email)
        name, domain = email.to_s.split('@', 2)
        return nil if domain.nil?

        "#{name.first}***@#{domain}"
      end
    end
  end
end
