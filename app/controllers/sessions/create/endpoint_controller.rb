# frozen_string_literal: true

module Sessions
  module Create
    class EndpointController < OresEndpointController
      ORES_ROUTE_NAME = "sessions".freeze

      prepend_view_path __dir__ if respond_to?(:prepend_view_path)

      def call
        dispatch_ores_endpoint(expected_route_name: ORES_ROUTE_NAME)
      end
    end
  end
end
