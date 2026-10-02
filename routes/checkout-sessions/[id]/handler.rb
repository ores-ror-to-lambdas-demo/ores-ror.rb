# frozen_string_literal: true

require_relative "../../../app/controllers/ores_endpoint_controller"
require_relative "../../../app/controllers/checkout_sessions/create/endpoint_controller"

module OresApp
  module PhysicalRouteHandlers
    module CheckoutSession
      module_function

      def call(request)
        CheckoutSessions::Create::EndpointController.call_ores_action("create", request)
      end
    end
  end
end
