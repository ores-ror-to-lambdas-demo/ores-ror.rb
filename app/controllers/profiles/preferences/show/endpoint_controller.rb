# frozen_string_literal: true
# ores-route: GET /profiles/:id/preferences action=show

module Profiles
  module Preferences
    module Show
      class EndpointController < OresEndpointController
        def show
          dispatch_ores_endpoint
        end
      end
    end
  end
end
