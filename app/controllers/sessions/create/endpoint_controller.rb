# frozen_string_literal: true

module Sessions
  module Create
    class EndpointController < OresEndpointController
      def create
        dispatch_ores_endpoint
      end
    end
  end
end
