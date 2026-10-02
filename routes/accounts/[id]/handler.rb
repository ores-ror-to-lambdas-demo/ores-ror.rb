# frozen_string_literal: true

require_relative "../../../app/controllers/ores_endpoint_controller"
require_relative "../../../app/controllers/accounts/show/endpoint_controller"

module OresApp
  module PhysicalRouteHandlers
    module Account
      module_function

      def call(request)
        ::Accounts::Show::EndpointController.call_ores_action("show", request)
      end
    end
  end
end
