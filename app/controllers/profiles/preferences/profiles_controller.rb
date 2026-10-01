# frozen_string_literal: true

module Profiles
  module Preferences
    class ProfilesController < ApplicationController
      def preferences
        dispatch_ores_endpoint
      end
    end
  end
end
