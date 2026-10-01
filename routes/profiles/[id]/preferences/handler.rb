# frozen_string_literal: true

module OresApp
  module RouteHandlers
    module Preferences
      module_function

      def call(request)
        Handlers.call("preferences", request)
      end
    end
  end
end
