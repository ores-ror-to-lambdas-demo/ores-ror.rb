# frozen_string_literal: true

require_relative "../../../app/controllers/ores_endpoint_controller"
require_relative "../../../app/controllers/recommendations/show/endpoint_controller"

module OresApp
  module PhysicalRouteHandlers
    module Recommendations
      module_function

      def call(request)
        Recommendations::Show::EndpointController.call_ores_action("show", request)
      end
    end
  end
end
