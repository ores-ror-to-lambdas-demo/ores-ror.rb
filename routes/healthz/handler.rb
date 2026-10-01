# frozen_string_literal: true

module OresApp
  module RouteHandlers
    module Health
      module_function

      def call(request)
        Handlers.call("health", request)
      end
    end
  end
end
