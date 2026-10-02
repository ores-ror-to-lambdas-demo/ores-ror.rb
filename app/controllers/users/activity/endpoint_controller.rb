# frozen_string_literal: true

module Users
  module Activity
    class EndpointController < OresEndpointController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
