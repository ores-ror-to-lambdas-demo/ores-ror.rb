# frozen_string_literal: true

module Search
  module Index
    class EndpointController < OresEndpointController
      def index
        dispatch_ores_endpoint
      end
    end
  end
end
