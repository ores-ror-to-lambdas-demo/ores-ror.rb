# frozen_string_literal: true
# ores-route: POST /checkout-sessions/:id action=create

module CheckoutSessions
  module Create
    class EndpointController < OresEndpointController
      def create
        dispatch_ores_endpoint
      end
    end
  end
end
