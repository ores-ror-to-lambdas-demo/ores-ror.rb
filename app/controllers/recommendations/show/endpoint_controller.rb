# frozen_string_literal: true
# ores-route: GET /recommendations/:id action=show

module Recommendations
  module Show
    class EndpointController < OresEndpointController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
