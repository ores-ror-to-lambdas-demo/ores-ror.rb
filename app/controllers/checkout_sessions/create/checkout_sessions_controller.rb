# frozen_string_literal: true

module CheckoutSessions
  module Create
    class CheckoutSessionsController < ApplicationController
      def create
        dispatch_ores_endpoint
      end
    end
  end
end
