# frozen_string_literal: true

class RecommendationsController < ApplicationController
  def show
    dispatch_ores
  end
end
