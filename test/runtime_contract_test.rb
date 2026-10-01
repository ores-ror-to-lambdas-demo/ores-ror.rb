# frozen_string_literal: true

require "test_helper"

class RuntimeContractTest < ActionDispatch::IntegrationTest
  test "health runs through a conventional Rails controller action" do
    get "/healthz", headers: { "x-request-id" => "contract-health" }
    assert response.successful?, response.body
    payload = JSON.parse(response.body)
    assert_equal true, payload.fetch("ok")
    assert_equal "ores-ror.rb", payload.fetch("service")
    assert_equal "rails", payload.fetch("execution_mode")
    assert payload.fetch("runtime").is_a?(String)
    assert_equal "contract-health", response.headers["x-request-id"]
  end

  test "Rails router recognizes conventional controller and action names" do
    assert_recognizes(
      { controller: "users/show/endpoint", action: "show", id: "demo-user" },
      { path: "/users/demo-user", method: :get }
    )
    assert_recognizes(
      { controller: "checkout_sessions/create/endpoint", action: "create", id: "cart-1" },
      { path: "/checkout-sessions/cart-1", method: :post }
    )
  end
end
