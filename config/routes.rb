# frozen_string_literal: true

require_relative "../lib/ores_app/routes"

Rails.application.routes.draw do
  OresApp::Routes.install_rails(self)
end
