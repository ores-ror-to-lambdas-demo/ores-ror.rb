# frozen_string_literal: true
# ores-route: GET /orders/:id action=show

module Orders
  module Show
    class EndpointController < OresEndpointController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
