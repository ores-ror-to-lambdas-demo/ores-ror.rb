# frozen_string_literal: true

module Users
  module Show
    class EndpointController < OresEndpointController
      ORES_ROUTE_NAME = "user".freeze

      prepend_view_path __dir__ if respond_to?(:prepend_view_path)

      def call
        dispatch_ores_endpoint(expected_route_name: ORES_ROUTE_NAME)
      end
    end
  end
end
