require "test_helper"

class RoutesTest < ActionDispatch::IntegrationTest
  test "demo route surface is present" do
    expected = %w[user cart checkout_session product order cancel_order account inventory recommendations search sessions preferences health]
    names = Rails.application.routes.routes.filter_map { |route| route.name&.to_s }
    assert_empty(expected - names)
  end

  test "every endpoint owns a conventional Rails controller folder and generated handler location" do
    expected = {
      "/users/:id" => ["app/controllers/users/show/users_controller.rb", "app/controllers/users/show/handler.rb"],
      "/carts/:id" => ["app/controllers/carts/show/carts_controller.rb", "app/controllers/carts/show/handler.rb"],
      "/checkout-sessions/:id" => ["app/controllers/checkout_sessions/create/checkout_sessions_controller.rb", "app/controllers/checkout_sessions/create/handler.rb"],
      "/products/:id" => ["app/controllers/products/show/products_controller.rb", "app/controllers/products/show/handler.rb"],
      "/orders/:id" => ["app/controllers/orders/show/orders_controller.rb", "app/controllers/orders/show/handler.rb"],
      "/orders/:id/cancel" => ["app/controllers/orders/cancel/orders_controller.rb", "app/controllers/orders/cancel/handler.rb"],
      "/accounts/:id" => ["app/controllers/accounts/show/accounts_controller.rb", "app/controllers/accounts/show/handler.rb"],
      "/inventory/:id" => ["app/controllers/inventory/show/inventory_controller.rb", "app/controllers/inventory/show/handler.rb"],
      "/recommendations/:id" => ["app/controllers/recommendations/show/recommendations_controller.rb", "app/controllers/recommendations/show/handler.rb"],
      "/search" => ["app/controllers/search/index/search_controller.rb", "app/controllers/search/index/handler.rb"],
      "/sessions" => ["app/controllers/sessions/create/sessions_controller.rb", "app/controllers/sessions/create/handler.rb"],
      "/profiles/:id/preferences" => ["app/controllers/profiles/preferences/profiles_controller.rb", "app/controllers/profiles/preferences/handler.rb"],
      "/healthz" => ["app/controllers/healthz/show/healthz_controller.rb", "app/controllers/healthz/show/handler.rb"]
    }

    actual = OresApp::Routes::TABLE.to_h do |route|
      [route.path, [OresApp::Routes.controller_relative_path(route), OresApp::Routes.handler_relative_path(route)]]
    end
    assert_equal expected, actual

    OresApp::Routes::TABLE.each do |route|
      assert File.file?(OresApp::Routes.controller_path(route)), "missing #{OresApp::Routes.controller_relative_path(route)}"
      refute File.file?(OresApp::Routes.handler_path(route)), "generated handler must not exist in a clean Rails checkout"
      assert_equal File.dirname(OresApp::Routes.controller_relative_path(route)), File.dirname(OresApp::Routes.handler_relative_path(route))
    end
  end
end
