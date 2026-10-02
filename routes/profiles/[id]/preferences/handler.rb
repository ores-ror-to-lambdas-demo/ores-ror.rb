# frozen_string_literal: true

module OresApp
  module PhysicalRouteHandlers
    module Preferences
      module_function
      def call(request)
        OresApp::Handlers.call("profiles/preferences/show/endpoint", "show", request)
      end
    end
  end
end
