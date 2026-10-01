class OrdersController < ApplicationController
  def show = run_ores_controller("orders", "show")
  def cancel = run_ores_controller("orders", "cancel")
end
