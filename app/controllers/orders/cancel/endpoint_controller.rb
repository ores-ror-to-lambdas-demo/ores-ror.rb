# frozen_string_literal: true
# ores-route: POST /orders/:id/cancel action=cancel

module Orders
  module Cancel
    class EndpointController < OresEndpointController
      def cancel
        dispatch_ores_endpoint
      end
    end
  end
end
