# frozen_string_literal: true

require "test_helper"

class RuntimeContractTest < ActionDispatch::IntegrationTest
  test "shared plain Ruby dispatcher reaches the health controller core" do
    result = OresApp::Dispatcher.call({
      "method" => "GET",
      "path" => "/healthz",
      "headers" => { "x-request-id" => "direct-health" }
    })

    assert_equal 200, result.fetch("status"), result.inspect
    payload = JSON.parse(result.fetch("body"))
    assert_equal true, payload.fetch("ok")
    assert_equal "direct-health", result.fetch("headers").fetch("x-request-id")
  end

  test "health runs through normal Rails controller and view" do
    get "/healthz", headers: { "x-request-id" => "contract-health" }
    assert response.successful?, response.body
    payload = JSON.parse(response.body)
    assert_equal true, payload.fetch("ok")
    assert_equal "ores-ror.rb", payload.fetch("service")
    assert_equal "rails", payload.fetch("execution_mode")
    assert payload.fetch("runtime").is_a?(String)
    assert_equal "contract-health", response.headers["x-request-id"]
  end

  test "Rails router uses the same controller action metadata as codegen" do
    assert_recognizes(
      { controller: "users", action: "show", id: "demo-user" },
      { path: "/users/demo-user", method: :get }
    )
    assert_recognizes(
      { controller: "checkout_sessions", action: "create", id: "cart-1" },
      { path: "/checkout-sessions/cart-1", method: :post }
    )
  end
end
