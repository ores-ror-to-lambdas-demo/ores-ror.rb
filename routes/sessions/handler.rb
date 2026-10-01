# frozen_string_literal: true

module OresApp
  module RouteHandlers
    module Sessions
      module_function

      def call(request)
        Handlers.call("create_session", request)
      end
    end
  end
end
