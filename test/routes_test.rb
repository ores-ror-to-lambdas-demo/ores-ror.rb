require "test_helper"

class RoutesTest < ActionDispatch::IntegrationTest
  EXPECTED = {
    "GET /users/:id" => "routes/users/[id]/handler.rb",
    "GET /carts/:id" => "routes/carts/[id]/handler.rb",
    "POST /checkout-sessions/:id" => "routes/checkout-sessions/[id]/handler.rb",
    "GET /products/:id" => "routes/products/[id]/handler.rb",
    "GET /orders/:id" => "routes/orders/[id]/handler.rb",
    "POST /orders/:id/cancel" => "routes/orders/[id]/cancel/handler.rb",
    "GET /accounts/:id" => "routes/accounts/[id]/handler.rb",
    "GET /inventory/:id" => "routes/inventory/[id]/handler.rb",
    "GET /recommendations/:id" => "routes/recommendations/[id]/handler.rb",
    "GET /search" => "routes/search/handler.rb",
    "POST /sessions" => "routes/sessions/handler.rb",
    "GET /profiles/:id/preferences" => "routes/profiles/[id]/preferences/handler.rb",
    "GET /healthz" => "routes/healthz/handler.rb"
  }.freeze

  test "demo route surface is installed into Rails from physical handlers" do
    expected_names = %w[user cart checkout_session product order cancel_order account inventory recommendations search sessions preferences health]
    names = Rails.application.routes.routes.filter_map { |route| route.name&.to_s }
    assert_empty(expected_names - names)
  end

  test "filesystem is authoritative for every HTTP route" do
    routes = OresApp::Routes.load_files!
    actual = routes.to_h { |route| ["#{route.verb} #{route.path}", route.source] }
    assert_equal EXPECTED, actual

    routes.each do |route|
      assert File.file?(OresApp::Routes.handler_path(route)), "missing #{route.source}"
      assert_equal route.path, OresApp::Routes.path_from_source(route.source)
    end
    assert OresApp::Routes.validate_filesystem!
  end

  test "orders has a real higher-level filesystem group handler" do
    OresApp::Routes.load_files!
    group = OresApp::Routes::GROUP_HANDLERS.fetch("orders")
    assert_equal "routes/orders/handler.rb", group.source
    assert File.file?(File.expand_path("../routes/orders/handler.rb", __dir__))
  end
end
