# frozen_string_literal: true

module Orders
  module Receipt
    class EndpointController < OresEndpointController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
