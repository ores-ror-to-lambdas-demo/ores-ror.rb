# frozen_string_literal: true

module OresApp
  module PhysicalRouteHandlers
    module Order
      module_function
      def call(request)
        OresApp::Handlers.call("orders/show/endpoint", "show", request)
      end
    end
  end
end
