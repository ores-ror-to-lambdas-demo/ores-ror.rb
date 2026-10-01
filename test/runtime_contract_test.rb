# frozen_string_literal: true

require "test_helper"

class RuntimeContractTest < ActionDispatch::IntegrationTest
  test "health runs through Rails adapter and shared dispatcher" do
    get "/healthz", headers: { "x-request-id" => "contract-health" }
    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal true, payload.fetch("ok")
    assert_equal "ores-ror.rb", payload.fetch("service")
    assert_equal "rails", payload.fetch("execution_mode")
    assert payload.fetch("runtime").is_a?(String)
    assert_equal "contract-health", response.headers["x-request-id"]
  end

  test "Rails router is generated from the shared route table" do
    assert_recognizes(
      { controller: "resources", action: "dispatch", ores_handler: "user", id: "demo-user" },
      { path: "/users/demo-user", method: :get }
    )
    assert_recognizes(
      { controller: "resources", action: "dispatch", ores_handler: "checkout_session", id: "cart-1" },
      { path: "/checkout-sessions/cart-1", method: :post }
    )
  end
end
