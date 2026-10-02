# frozen_string_literal: true

require_relative "../../app/controllers/ores_endpoint_controller"
require_relative "../../app/controllers/sessions/create/endpoint_controller"

module OresApp
  module PhysicalRouteHandlers
    module CreateSession
      module_function

      def call(request)
        ::Sessions::Create::EndpointController.call_ores_action("create", request)
      end
    end
  end
end
