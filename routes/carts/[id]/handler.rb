# frozen_string_literal: true

require_relative "../../../app/controllers/ores_endpoint_controller"
require_relative "../../../app/controllers/carts/show/endpoint_controller"

module OresApp
  module PhysicalRouteHandlers
    module Cart
      module_function

      def call(request)
        Carts::Show::EndpointController.call_ores_action("show", request)
      end
    end
  end
end
