# frozen_string_literal: true

class HealthController < ApplicationController
  def show
    dispatch_ores
  end
end
