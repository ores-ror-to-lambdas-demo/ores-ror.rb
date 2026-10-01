# frozen_string_literal: true

class CheckoutSessionsController < ApplicationController
  def create
    dispatch_ores
  end
end
