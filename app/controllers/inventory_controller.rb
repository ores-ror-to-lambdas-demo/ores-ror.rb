# frozen_string_literal: true

class InventoryController < ApplicationController
  def show
    dispatch_ores
  end
end
