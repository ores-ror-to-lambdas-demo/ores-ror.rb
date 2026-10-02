# frozen_string_literal: true

module OresApp
  module PhysicalRouteHandlers
    module OrderReceipt
      module_function
      def call(request)
        OresApp::Handlers.call("orders/receipt/endpoint", "show", request)
      end
    end
  end
end
