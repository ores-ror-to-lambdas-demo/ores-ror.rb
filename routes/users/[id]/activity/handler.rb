# frozen_string_literal: true

module OresApp
  module PhysicalRouteHandlers
    module UserActivity
      module_function
      def call(request)
        OresApp::Handlers.call("users/activity/endpoint", "show", request)
      end
    end
  end
end
