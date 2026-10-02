require "test_helper"

class RoutesTest < ActionDispatch::IntegrationTest
  test "Rails routes are the only endpoint routing source of truth" do
    expected = {
      "user" => ["users/show/endpoint", "show"],
      "user_activity" => ["users/activity/endpoint", "show"],
      "cart" => ["carts/show/endpoint", "show"],
      "checkout_session" => ["checkout_sessions/create/endpoint", "create"],
      "product" => ["products/show/endpoint", "show"],
      "order" => ["orders/show/endpoint", "show"],
      "order_receipt" => ["orders/receipt/endpoint", "show"],
      "cancel_order" => ["orders/cancel/endpoint", "cancel"],
      "account" => ["accounts/show/endpoint", "show"],
      "inventory" => ["inventory/show/endpoint", "show"],
      "recommendations" => ["recommendations/show/endpoint", "show"],
      "search" => ["search/index/endpoint", "index"],
      "create_session" => ["sessions/create/endpoint", "create"],
      "preferences" => ["profiles/preferences/show/endpoint", "show"],
      "health" => ["healthz/show/endpoint", "show"]
    }

    actual = Rails.application.routes.routes.each_with_object({}) do |route, out|
      next unless route.name && expected.key?(route.name.to_s)

      out[route.name.to_s] = [route.defaults[:controller], route.defaults[:action]]
    end

    assert_operator expected.length, :>=, 15
    assert_equal expected, actual
  end

  test "Rails route middleware metadata is identical to the static Graal route contract" do
    require Rails.root.join("lib/ores_build/static_routes")

    static_routes = OresBuild::StaticRoutes.new(Rails.root).compile.index_by { |route| route.fetch(:name) }
    rails_routes = Rails.application.routes.routes.each_with_object({}) do |route, out|
      next unless route.name && static_routes.key?(route.name.to_s)
      out[route.name.to_s] = route
    end

    expected = {
      "user" => %w[request_id users_show_header],
      "cancel_order" => %w[request_id order_cancel_header],
      "search" => %w[request_id search_header]
    }

    static_routes.each do |name, route|
      rails_route = rails_routes.fetch(name)
      raw = rails_route.defaults[:ores_middleware] || rails_route.defaults["ores_middleware"]
      assert raw, "#{name} must declare ores_middleware in config/routes.rb"
      rails_chain = OresApp::Middleware.normalize_names(raw)
      assert_equal route.fetch(:middleware), rails_chain, "#{name} middleware drift between Rails and Graal compiler"
      assert_equal expected.fetch(name, %w[request_id]), rails_chain, "#{name} has unexpected middleware chain"
    end
  end

  test "every endpoint has a conventional app model and json plus html erb views" do
    require Rails.root.join("lib/ores_build/static_routes")

    OresBuild::StaticRoutes.new(Rails.root).compile.each do |route|
      assert route.fetch(:controller_file).start_with?("app/controllers/")
      assert route.fetch(:model_file).start_with?("app/models/")
      assert File.file?(Rails.root.join(route.fetch(:model_file))), route.inspect
      assert route.fetch(:view_files).any? { |file| file.start_with?("app/views/") && file.end_with?(".json.erb") }, route.inspect
      assert route.fetch(:view_files).any? { |file| file.start_with?("app/views/") && file.end_with?(".html.erb") }, route.inspect
    end
  end

  test "each endpoint action is a normal Rails method under app/controllers" do
    Rails.application.eager_load!

    Rails.application.routes.routes.each do |route|
      next unless route.name

      controller = route.defaults[:controller].to_s
      action = route.defaults[:action].to_s
      next if controller.empty? || action.empty?

      klass = "#{controller.camelize}Controller".constantize
      source = klass.instance_method(action).source_location&.first
      assert source&.include?("/app/controllers/"), "#{controller}##{action} is not backed by app/controllers"
    end
  end
end
