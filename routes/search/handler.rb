# frozen_string_literal: true

module OresApp
  module RouteHandlers
    module Search
      module_function

      def call(request)
        Handlers.call("search", request)
      end
    end
  end
end
