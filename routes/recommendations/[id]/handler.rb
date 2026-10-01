# frozen_string_literal: true

module OresApp
  module RouteHandlers
    module Recommendations
      module_function

      def call(request)
        Handlers.call("recommendations", request)
      end
    end
  end
end
