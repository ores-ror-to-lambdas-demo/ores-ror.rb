# frozen_string_literal: true

module Inventory
  module Show
    class InventoryController < ApplicationController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
