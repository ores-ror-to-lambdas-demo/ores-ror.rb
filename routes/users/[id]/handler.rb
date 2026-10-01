# frozen_string_literal: true

module OresApp
  module RouteHandlers
    module User
      module_function

      def call(request)
        Handlers.call("user", request)
      end
    end
  end
end
