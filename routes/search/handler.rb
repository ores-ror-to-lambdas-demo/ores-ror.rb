# frozen_string_literal: true

require_relative "../../app/controllers/ores_endpoint_controller"
require_relative "../../app/controllers/search/index/endpoint_controller"

module OresApp
  module PhysicalRouteHandlers
    module Search
      module_function

      def call(request)
        ::Search::Index::EndpointController.call_ores_action("index", request)
      end
    end
  end
end
