# frozen_string_literal: true

module Orders
  module Show
    class OrdersController < ApplicationController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
