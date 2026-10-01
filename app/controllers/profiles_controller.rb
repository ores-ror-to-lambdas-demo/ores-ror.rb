class ProfilesController < ApplicationController
  def preferences = run_ores_controller("profiles", "preferences")
end
