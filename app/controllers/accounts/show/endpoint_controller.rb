# frozen_string_literal: true
# ores-route: GET /accounts/:id action=show

module Accounts
  module Show
    class EndpointController < OresEndpointController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
