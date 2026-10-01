# frozen_string_literal: true

module OresApp
  module RouteHandlers
    module Inventory
      module_function

      def call(request)
        Handlers.call("inventory", request)
      end
    end
  end
end
