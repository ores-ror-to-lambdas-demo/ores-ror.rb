# frozen_string_literal: true
# ores-route: GET /orders/:id/receipt action=show

module Orders
  module Receipt
    class EndpointController < OresEndpointController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
