# frozen_string_literal: true

module Products
  module Show
    class ProductsController < ApplicationController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
