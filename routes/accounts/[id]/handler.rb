# frozen_string_literal: true

module OresApp
  module PhysicalRouteHandlers
    module Account
      module_function
      def call(request)
        OresApp::Handlers.call("accounts/show/endpoint", "show", request)
      end
    end
  end
end
