# frozen_string_literal: true

module OresApp
  module RouteHandlers
    module Cart
      module_function

      def call(request)
        Handlers.call("cart", request)
      end
    end
  end
end
