# frozen_string_literal: true
# ores-route: GET /users/:id action=show

module Users
  module Show
    class EndpointController < OresEndpointController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
