# frozen_string_literal: true
# ores-route: GET /users/:id/activity action=show

module Users
  module Activity
    class EndpointController < OresEndpointController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
