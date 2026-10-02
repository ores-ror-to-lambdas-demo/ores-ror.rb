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
    # ores-route: GET /admin/users action=index
    # ores-route: GET /admin/users/:id action=show
    module Admin
      class UsersController
        def index; end
        def show; end
      end
    end
  RUBY

  File.write(File.join(root, "app/controllers/api/widgets_controller.rb"), <<~RUBY)
    # ores-route: GET /v1/widgets action=index
    # ores-route: GET /v1/widgets/:id action=show
    # ores-route: PATCH /v1/widgets/:id action=update
    # ores-route: PUT /v1/widgets/:id action=update
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
    File.write(File.join(root, "app/views/admin/users/#{action}.html.erb"), "<pre data-ores-payload><%= model.html_json_view %></pre>\n")
  end
  %w[index show update].each do |action|
    File.write(File.join(root, "app/views/api/widgets/#{action}.json.erb"), "<%= JSON.generate(model.to_h) %>\n")
    File.write(File.join(root, "app/views/api/widgets/#{action}.html.erb"), "<pre data-ores-payload><%= model.html_json_view %></pre>\n")
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
  raise "expected every smoke route to be controller-annotated" unless routes.all? { |route| route.fetch(:controller_route_annotated) }
  raise "annotation metadata missing" unless routes.all? { |route| route.fetch(:controller_route_annotation).start_with?("# ores-route:") }
end

puts "static Rails route compiler smoke: ok"
