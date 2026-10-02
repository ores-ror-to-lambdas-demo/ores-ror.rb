# frozen_string_literal: true

module OresApp
  module PhysicalRouteHandlers
    module Health
      module_function
      def call(request)
        OresApp::Handlers.call("healthz/show/endpoint", "show", request)
      end
    end
  end
end
