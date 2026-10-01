# frozen_string_literal: true

module OresApp
  module RouteHandlers
    module Product
      module_function

      def call(request)
        Handlers.call("product", request)
      end
    end
  end
end
