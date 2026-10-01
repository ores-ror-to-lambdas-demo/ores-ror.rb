require "test_helper"
require_relative "../lib/ores_app/route_handlers"

class RoutesTest < ActionDispatch::IntegrationTest
  test "demo route surface is present" do
    expected = %w[user cart checkout_session product order cancel_order account inventory recommendations search sessions preferences health]
    names = Rails.application.routes.routes.filter_map { |route| route.name&.to_s }
    assert_empty(expected - names)
  end

  test "every declared route has a committed URL-shaped handler" do
    expected = {
      "/users/:id" => "routes/users/[id]/handler.rb",
      "/carts/:id" => "routes/carts/[id]/handler.rb",
      "/checkout-sessions/:id" => "routes/checkout-sessions/[id]/handler.rb",
      "/products/:id" => "routes/products/[id]/handler.rb",
      "/orders/:id" => "routes/orders/[id]/handler.rb",
      "/orders/:id/cancel" => "routes/orders/[id]/cancel/handler.rb",
      "/accounts/:id" => "routes/accounts/[id]/handler.rb",
      "/inventory/:id" => "routes/inventory/[id]/handler.rb",
      "/recommendations/:id" => "routes/recommendations/[id]/handler.rb",
      "/search" => "routes/search/handler.rb",
      "/sessions" => "routes/sessions/handler.rb",
      "/profiles/:id/preferences" => "routes/profiles/[id]/preferences/handler.rb",
      "/healthz" => "routes/healthz/handler.rb"
    }

    actual = OresApp::Routes::TABLE.to_h { |route| [route.path, OresApp::Routes.handler_relative_path(route)] }
    assert_equal expected, actual

    OresApp::Routes::TABLE.each do |route|
      assert File.file?(OresApp::Routes.handler_path(route)), "missing #{OresApp::Routes.handler_relative_path(route)}"
    end
  end

  test "route table and filesystem handler tree are an exact contract" do
    assert OresApp::Routes.validate!
    assert OresApp::RouteHandlers.validate!

    expected = OresApp::Routes::TABLE.map { |route| OresApp::Routes.handler_relative_path(route) }.sort
    assert_equal expected, OresApp::Routes.filesystem_handler_paths
  end
end
