# frozen_string_literal: true
# ores-route: GET /carts/:id action=show

module Carts
  module Show
    class EndpointController < OresEndpointController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
