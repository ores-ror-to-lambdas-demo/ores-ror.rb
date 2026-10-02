# frozen_string_literal: true

module OresApp
  module PhysicalRouteHandlers
    module Product
      module_function
      def call(request)
        OresApp::Handlers.call("products/show/endpoint", "show", request)
      end
    end
  end
end
