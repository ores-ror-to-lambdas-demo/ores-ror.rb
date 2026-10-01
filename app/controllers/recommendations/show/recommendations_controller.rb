# frozen_string_literal: true

module Recommendations
  module Show
    class RecommendationsController < ApplicationController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
