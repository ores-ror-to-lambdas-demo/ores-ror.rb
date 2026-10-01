# frozen_string_literal: true

module OresApp
  module RouteHandlers
    module Order
      module_function

      def call(request)
        Handlers.call("order", request)
      end
    end
  end
end
