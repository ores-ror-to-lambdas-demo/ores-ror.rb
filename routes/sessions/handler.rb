# frozen_string_literal: true

module OresApp
  module PhysicalRouteHandlers
    module CreateSession
      module_function
      def call(request)
        OresApp::Handlers.call("sessions/create/endpoint", "create", request)
      end
    end
  end
end
