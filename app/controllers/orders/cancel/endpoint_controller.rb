# frozen_string_literal: true

module Orders
  module Cancel
    class EndpointController < OresEndpointController
      def cancel
        dispatch_ores_endpoint
      end
    end
  end
end
