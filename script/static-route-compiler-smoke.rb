#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "../lib/ores_build/static_routes"

Dir.mktmpdir("ores-static-routes") do |root|
  FileUtils.mkdir_p(File.join(root, "config"))
  FileUtils.mkdir_p(File.join(root, "app/controllers/admin"))
  FileUtils.mkdir_p(File.join(root, "app/controllers/api"))
  FileUtils.mkdir_p(File.join(root, "app/models"))
  FileUtils.mkdir_p(File.join(root, "app/views/admin/users"))
  FileUtils.mkdir_p(File.join(root, "app/views/api/widgets"))

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

  File.write(File.join(root, "app/models/application_model.rb"), "class ApplicationModel; end\n")
  File.write(File.join(root, "app/models/user.rb"), "class User < ApplicationModel; end\n")
  File.write(File.join(root, "app/models/widget.rb"), "class Widget < ApplicationModel; end\n")

  %w[index show].each do |action|
    File.write(File.join(root, "app/views/admin/users/#{action}.json.erb"), "<%= JSON.generate(model.to_h) %>\n")
  end
  %w[index show update].each do |action|
    File.write(File.join(root, "app/views/api/widgets/#{action}.json.erb"), "<%= JSON.generate(model.to_h) %>\n")
  end

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
