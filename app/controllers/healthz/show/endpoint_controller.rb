# frozen_string_literal: true
# ores-route: GET /healthz action=show

module Healthz
  module Show
    class EndpointController < OresEndpointController
      ores_cpu_bound!

      def show
        dispatch_ores_endpoint
      end
    end
  end
end
