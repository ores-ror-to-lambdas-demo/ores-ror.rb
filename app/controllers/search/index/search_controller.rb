# frozen_string_literal: true

module Search
  module Index
    class SearchController < ApplicationController
      def index
        dispatch_ores_endpoint
      end
    end
  end
end
