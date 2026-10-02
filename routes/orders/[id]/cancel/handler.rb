# frozen_string_literal: true

require_relative "../../../../app/controllers/ores_endpoint_controller"
require_relative "../../../../app/controllers/orders/cancel/endpoint_controller"

module OresApp
  module PhysicalRouteHandlers
    module CancelOrder
      module_function

      def call(request)
        ::Orders::Cancel::EndpointController.call_ores_action("cancel", request)
      end
    end
  end
end
