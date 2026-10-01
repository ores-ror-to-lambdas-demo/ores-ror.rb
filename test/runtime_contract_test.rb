require "test_helper"

class RuntimeContractTest < ActionDispatch::IntegrationTest
  test "health runs through the Rails application" do
    get "/healthz", headers: { "x-request-id" => "contract-health" }
    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal true, payload.fetch("ok")
    assert_equal "ores-ror.rb", payload.fetch("service")
    assert payload.fetch("runtime").is_a?(String)
  end

  test "resource routes are owned by the same Rails router in every runtime" do
    assert_recognizes(
      { controller: "resources", action: "user", id: "demo-user" },
      { path: "/users/demo-user", method: :get }
    )
    assert_recognizes(
      { controller: "resources", action: "checkout_session", id: "cart-1" },
      { path: "/checkout-sessions/cart-1", method: :post }
    )
  end
end
