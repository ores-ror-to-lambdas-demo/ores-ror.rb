# frozen_string_literal: true
# ores-route: GET /inventory/:id action=show

module Inventory
  module Show
    class EndpointController < OresEndpointController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
