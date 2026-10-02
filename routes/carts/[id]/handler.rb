# frozen_string_literal: true

module OresApp
  module PhysicalRouteHandlers
    module Cart
      module_function
      def call(request)
        OresApp::Handlers.call("carts/show/endpoint", "show", request)
      end
    end
  end
end
