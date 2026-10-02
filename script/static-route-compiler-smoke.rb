#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "../lib/ores_build/static_routes"

Dir.mktmpdir("ores-static-routes") do |root|
  FileUtils.mkdir_p(File.join(root, "config"))
  FileUtils.mkdir_p(File.join(root, "app/controllers/admin"))
  FileUtils.mkdir_p(File.join(root, "app/controllers/api"))

  File.write(File.join(root, "config/routes.rb"), <<~ROUTES)
    Rails.application.routes.draw do
      namespace :admin do
        resources :users, only: [:index, :show]
      end

      scope "/v1", module: "api", as: "v1" do
        resources :widgets, only: [:index, :show, :update]
      end
    end
  ROUTES

  File.write(File.join(root, "app/controllers/admin/users_controller.rb"), <<~RUBY)
    module Admin
      class UsersController
        def index; end
        def show; end
      end
    end
  RUBY

  File.write(File.join(root, "app/controllers/api/widgets_controller.rb"), <<~RUBY)
    module Api
      class WidgetsController
        def index; end
        def show; end
        def update; end
      end
    end
  RUBY

  routes = OresBuild::StaticRoutes.new(root).compile
  pairs = routes.map { |route| [route.fetch(:verb), route.fetch(:path), route.fetch(:controller), route.fetch(:action)] }
  expected = [
    ["GET", "/admin/users", "admin/users", "index"],
    ["GET", "/admin/users/:id", "admin/users", "show"],
    ["GET", "/v1/widgets", "api/widgets", "index"],
    ["GET", "/v1/widgets/:id", "api/widgets", "show"],
    ["PATCH", "/v1/widgets/:id", "api/widgets", "update"],
    ["PUT", "/v1/widgets/:id", "api/widgets", "update"]
  ]
  raise "route compiler mismatch: #{pairs.inspect}" unless pairs == expected
end

puts "static Rails route compiler smoke: ok"
