# frozen_string_literal: true

module Orders
  module Cancel
    class OrdersController < ApplicationController
      def cancel
        dispatch_ores_endpoint
      end
    end
  end
end
