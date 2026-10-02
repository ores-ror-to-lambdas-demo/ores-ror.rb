# frozen_string_literal: true

module OresApp
  module PhysicalRouteHandlers
    module Search
      module_function
      def call(request)
        OresApp::Handlers.call("search/index/endpoint", "index", request)
      end
    end
  end
end
