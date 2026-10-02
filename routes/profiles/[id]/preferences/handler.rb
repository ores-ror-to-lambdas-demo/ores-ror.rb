# frozen_string_literal: true

require_relative "../../../../app/controllers/ores_endpoint_controller"
require_relative "../../../../app/controllers/profiles/preferences/show/endpoint_controller"

module OresApp
  module PhysicalRouteHandlers
    module Preferences
      module_function

      def call(request)
        Profiles::Preferences::Show::EndpointController.call_ores_action("show", request)
      end
    end
  end
end
