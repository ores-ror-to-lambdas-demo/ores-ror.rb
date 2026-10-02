# frozen_string_literal: true

module CheckoutSessions
  module Create
    class EndpointController < OresEndpointController
      def create
        dispatch_ores_endpoint
      end
    end
  end
end
