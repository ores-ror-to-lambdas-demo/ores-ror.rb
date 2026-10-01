# frozen_string_literal: true

module Sessions
  module Create
    class SessionsController < ApplicationController
      def create
        dispatch_ores_endpoint
      end
    end
  end
end
