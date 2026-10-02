# frozen_string_literal: true

require_relative "../../../../app/controllers/ores_endpoint_controller"
require_relative "../../../../app/controllers/orders/receipt/endpoint_controller"

module OresApp
  module PhysicalRouteHandlers
    module OrderReceipt
      module_function

      def call(request)
        Orders::Receipt::EndpointController.call_ores_action("show", request)
      end
    end
  end
end
