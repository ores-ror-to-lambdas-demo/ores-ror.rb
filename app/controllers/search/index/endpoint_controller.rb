# frozen_string_literal: true
# ores-route: GET /search action=index

module Search
  module Index
    class EndpointController < OresEndpointController
      def index
        dispatch_ores_endpoint
      end
    end
  end
end
