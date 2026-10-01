# frozen_string_literal: true

require "test_helper"

class RuntimeContractTest < ActionDispatch::IntegrationTest
  test "health runs through its endpoint-specific Rails controller" do
    get "/healthz", headers: { "x-request-id" => "contract-health" }
    assert response.successful?, response.body
    payload = JSON.parse(response.body)
    assert_equal true, payload.fetch("ok")
    assert_equal "ores-ror.rb", payload.fetch("service")
    assert_equal "rails", payload.fetch("execution_mode")
    assert payload.fetch("runtime").is_a?(String)
    assert_equal "contract-health", response.headers["x-request-id"]
  end

  test "Rails router maps endpoints to colocated controller directories" do
    assert_recognizes(
      { controller: "users/show/endpoint", action: "call", ores_handler: "user", ores_route_name: "user", id: "demo-user" },
      { path: "/users/demo-user", method: :get }
    )
    assert_recognizes(
      { controller: "checkout_sessions/create/endpoint", action: "call", ores_handler: "checkout_session", ores_route_name: "checkout_session", id: "cart-1" },
      { path: "/checkout-sessions/cart-1", method: :post }
    )
  end
end
