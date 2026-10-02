# frozen_string_literal: true

module OresApp
  module PhysicalRouteHandlers
    module User
      module_function
      def call(request)
        OresApp::Handlers.call("users/show/endpoint", "show", request)
      end
    end
  end
end
