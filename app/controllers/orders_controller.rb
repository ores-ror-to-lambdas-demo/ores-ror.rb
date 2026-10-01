# frozen_string_literal: true

class OrdersController < ApplicationController
  def show
    dispatch_ores
  end

  def cancel
    dispatch_ores
  end
end
