# frozen_string_literal: true

module OresApp
  module RouteHandlers
    module CancelOrder
      module_function

      def call(request)
        Handlers.call("cancel_order", request)
      end
    end
  end
end
