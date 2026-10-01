# frozen_string_literal: true

module Accounts
  module Show
    class AccountsController < ApplicationController
      def show
        dispatch_ores_endpoint
      end
    end
  end
end
