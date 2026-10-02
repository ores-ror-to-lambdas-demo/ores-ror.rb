# frozen_string_literal: true

module OresApp
  module PhysicalRouteHandlers
    module CancelOrder
      module_function
      def call(request)
        OresApp::Handlers.call("orders/cancel/endpoint", "cancel", request)
      end
    end
  end
end
