# frozen_string_literal: true

require "test_helper"

class RuntimeContractTest < ActionDispatch::IntegrationTest
  test "shared dispatcher reaches health business logic directly" do
    result = OresApp::Dispatcher.call(
      "method" => "GET",
      "path" => "/healthz",
      "headers" => { "x-request-id" => "direct-health" }
    )

    assert_equal 200, result.fetch("status"), result.inspect
    payload = JSON.parse(result.fetch("body"))
    assert_equal true, payload.fetch("ok")
    assert_equal "direct-health", result.fetch("headers").fetch("x-request-id")
  end

  test "health runs through its own Rails endpoint controller" do
    get "/healthz", headers: { "x-request-id" => "contract-health" }
    assert response.successful?, response.body
    payload = JSON.parse(response.body)
    assert_equal true, payload.fetch("ok")
    assert_equal "ores-ror.rb", payload.fetch("service")
    assert_equal "rails", payload.fetch("execution_mode")
    assert payload.fetch("runtime").is_a?(String)
    assert_equal "contract-health", response.headers["x-request-id"]
  end

  test "Rails routes point to endpoint-specific controller namespaces" do
    assert_recognizes(
      { controller: "users/show/users", action: "show", id: "demo-user" },
      { path: "/users/demo-user", method: :get }
    )
    assert_recognizes(
      { controller: "checkout_sessions/create/checkout_sessions", action: "create", id: "cart-1" },
      { path: "/checkout-sessions/cart-1", method: :post }
    )
    assert_recognizes(
      { controller: "orders/cancel/orders", action: "cancel", id: "order-1" },
      { path: "/orders/order-1/cancel", method: :post }
    )
  end
end
