# frozen_string_literal: true

module Healthz
  module Show
    class HealthzController < ApplicationController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
