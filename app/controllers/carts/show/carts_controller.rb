# frozen_string_literal: true

module Carts
  module Show
    class CartsController < ApplicationController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
