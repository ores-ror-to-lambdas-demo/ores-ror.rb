# frozen_string_literal: true

module Users
  module Show
    class UsersController < ApplicationController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
