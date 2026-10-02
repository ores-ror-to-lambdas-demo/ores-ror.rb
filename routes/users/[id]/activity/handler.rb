# frozen_string_literal: true

require_relative "../../../../app/controllers/ores_endpoint_controller"
require_relative "../../../../app/controllers/users/activity/endpoint_controller"

module OresApp
  module PhysicalRouteHandlers
    module UserActivity
      module_function

      def call(request)
        Users::Activity::EndpointController.call_ores_action("show", request)
      end
    end
  end
end
