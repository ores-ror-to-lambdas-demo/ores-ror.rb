# frozen_string_literal: true

module Search
  module Index
    class EndpointController < OresEndpointController
      ORES_ROUTE_NAME = "search".freeze

      prepend_view_path __dir__ if respond_to?(:prepend_view_path)

      def call
        dispatch_ores_endpoint(expected_route_name: ORES_ROUTE_NAME)
      end
    end
  end
end
