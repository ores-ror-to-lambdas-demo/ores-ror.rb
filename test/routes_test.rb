require "test_helper"

class RoutesTest < ActionDispatch::IntegrationTest
  test "demo route surface is present" do
    expected = %w[user cart checkout_session product order cancel_order account inventory recommendations search sessions preferences health]
    names = Rails.application.routes.named_routes.route_names.map(&:to_s)
    assert_empty(expected - names)
  end
end
