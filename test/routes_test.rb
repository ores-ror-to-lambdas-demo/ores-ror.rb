require "test_helper"

class RoutesTest < ActionDispatch::IntegrationTest
  test "demo route surface is present" do
    expected = %w[user cart checkout_session product order cancel_order account inventory recommendations search sessions preferences health]
    names = Rails.application.routes.routes.filter_map { |route| route.name&.to_s }
    assert_empty(expected - names)
  end

  test "every route owns a tracked endpoint controller directory and generated handler location" do
    OresApp::Routes::TABLE.each do |route|
      assert File.file?(OresApp::Routes.controller_path(route)), "missing #{OresApp::Routes.controller_relative_path(route)}"
      assert_equal File.join(route.endpoint_dir, "handler.rb"), OresApp::Routes.handler_relative_path(route)
      assert_equal "#{route.endpoint_dir.delete_prefix("app/controllers/")}/endpoint", route.controller
      assert_equal "call", route.action
    end
  end
end
