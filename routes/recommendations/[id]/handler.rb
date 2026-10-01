# frozen_string_literal: true

module OresApp
  module PhysicalRouteHandlers
    module Recommendations
      module_function
      def call(request)
        OresApp::Handlers.call("recommendations/show/endpoint", "show", request)
      end
    end
  end
end
