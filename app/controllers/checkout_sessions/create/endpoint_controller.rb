# frozen_string_literal: true

module CheckoutSessions
  module Create
    class EndpointController < OresEndpointController
      ORES_ROUTE_NAME = "checkout_session".freeze

      prepend_view_path __dir__ if respond_to?(:prepend_view_path)

      def call
        dispatch_ores_endpoint(expected_route_name: ORES_ROUTE_NAME)
      end
    end
  end
end
