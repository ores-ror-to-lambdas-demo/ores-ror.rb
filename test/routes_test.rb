require "test_helper"

class RoutesTest < ActionDispatch::IntegrationTest
  test "demo route surface is present" do
    expected = %w[user cart checkout_session product order cancel_order account inventory recommendations search sessions preferences health]
    names = Rails.application.routes.routes.filter_map { |route| route.name&.to_s }
    assert_empty(expected - names)
  end

  test "lambda filesystem is generated only under generated lambda routes" do
    refute Dir.exist?(Rails.root.join("routes")), "authored routes/ handler tree must not exist"

    expected = {
      "/users/:id" => "users/[id]/handler.rb",
      "/carts/:id" => "carts/[id]/handler.rb",
      "/checkout-sessions/:id" => "checkout-sessions/[id]/handler.rb",
      "/products/:id" => "products/[id]/handler.rb",
      "/orders/:id" => "orders/[id]/handler.rb",
      "/orders/:id/cancel" => "orders/[id]/cancel/handler.rb",
      "/accounts/:id" => "accounts/[id]/handler.rb",
      "/inventory/:id" => "inventory/[id]/handler.rb",
      "/recommendations/:id" => "recommendations/[id]/handler.rb",
      "/search" => "search/handler.rb",
      "/sessions" => "sessions/handler.rb",
      "/profiles/:id/preferences" => "profiles/[id]/preferences/handler.rb",
      "/healthz" => "healthz/handler.rb"
    }

    actual = OresApp::Routes::TABLE.to_h { |route| [route.path, OresApp::Routes.lambda_route_relative_path(route)] }
    assert_equal expected, actual

    OresApp::Routes::TABLE.each do |route|
      assert File.file?(OresApp::Routes.controller_source_path(route)), "missing controller for #{route.path}"
      assert File.file?(OresApp::Routes.view_source_path(route)), "missing view for #{route.path}"
    end
  end
end
