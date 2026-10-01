# frozen_string_literal: true

module OresApp
  module PhysicalRouteHandlers
    module Inventory
      module_function
      def call(request)
        OresApp::Handlers.call("inventory/show/endpoint", "show", request)
      end
    end
  end
end
