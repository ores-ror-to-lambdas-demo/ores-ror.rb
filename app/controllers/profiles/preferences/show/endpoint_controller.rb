# frozen_string_literal: true

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
