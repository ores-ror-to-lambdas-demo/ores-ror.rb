# frozen_string_literal: true

require "test_helper"

class FilesystemRoutesTest < ActiveSupport::TestCase
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

  test "every HTTP route is backed by a committed physical handler" do
    routes = OresApp::Routes.load_files!
    actual = routes.to_h do |route|
      ["#{route.verb} #{route.path}", route.source]
    end

    assert_equal EXPECTED, actual
    routes.each do |route|
      assert File.file?(OresApp::Routes.physical_path(route.source)), "missing #{route.source}"
      assert_equal route.path, OresApp::Routes.path_from_source(route.source)
    end
    assert OresApp::Routes.validate_filesystem!
  end

  test "orders has a real higher-level group handler" do
    group = OresApp::Routes::GROUP_HANDLERS.fetch("orders")
    assert_equal "routes/orders/handler.rb", group.source
    assert File.file?(OresApp::Routes.physical_path(group.source))
  end
end
