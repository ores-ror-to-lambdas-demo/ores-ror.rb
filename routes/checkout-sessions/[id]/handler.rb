# frozen_string_literal: true

module OresApp
  module PhysicalRouteHandlers
    module CheckoutSession
      module_function
      def call(request)
        OresApp::Handlers.call("checkout_sessions/create/endpoint", "create", request)
      end
    end
  end
end
