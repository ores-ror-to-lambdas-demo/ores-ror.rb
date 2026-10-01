# frozen_string_literal: true

module OresApp
  module RouteHandlers
    module CheckoutSession
      module_function

      def call(request)
        Handlers.call("checkout_session", request)
      end
    end
  end
end
