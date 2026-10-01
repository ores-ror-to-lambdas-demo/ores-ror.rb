# frozen_string_literal: true

module OresApp
  module RouteHandlers
    module Account
      module_function

      def call(request)
        Handlers.call("account", request)
      end
    end
  end
end
