# frozen_string_literal: true

require "test_helper"

class RuntimeContractTest < ActionDispatch::IntegrationTest
  test "health runs through a conventional Rails controller action" do
    get "/healthz", headers: { "accept" => "application/json", "x-request-id" => "contract-health" }
    assert response.successful?, response.body
    payload = JSON.parse(response.body)
    assert_equal true, payload.fetch("ok")
    assert_equal "ores-ror.rb", payload.fetch("service")
    assert_equal "contract-health", response.headers["x-request-id"]
    assert_equal "request_id", response.headers["x-ores-middleware-chain"]
    assert_equal "rails", response.headers["x-ores-execution-mode"]
    assert response.headers["x-ores-runtime"].to_s.length > 0
    assert_equal "application/json", response.media_type
    assert HealthzRecord < ApplicationModel
  end

  test "Rails router recognizes conventional controller and action names" do
    assert_recognizes(
      { controller: "users/show/endpoint", action: "show", id: "demo-user", ores_middleware: "request_id,users_show_header" },
      { path: "/users/demo-user", method: :get }
    )
    assert_recognizes(
      { controller: "checkout_sessions/create/endpoint", action: "create", id: "cart-1", ores_middleware: "request_id" },
      { path: "/checkout-sessions/cart-1", method: :post }
    )
  end

  test "product action fans out independent data reads without bypassing the controller" do
    source = File.read(Rails.root.join("app/controllers/products/show/endpoint_controller.rb"))
    refute_includes source, "dispatch_ores_endpoint"
    assert_includes source, "parallel_requests"

    calls = []
    mock = lambda do |method, path, body: nil, query: {}|
      calls << path
      {
        status: 200,
        body: {
          "ok" => true,
          "method" => method.to_s.upcase,
          "path" => path,
          "query" => query,
          "body" => body
        }
      }
    end

    OresApp::HttpDatabase.stub(:request, mock) do
      get "/products/demo-product", headers: {
        "accept" => "application/json",
        "x-request-id" => "direct-controller-product"
      }
    end

    assert_response :success
    assert_equal "direct", response.headers["x-ores-controller-execution"]
    assert_equal "request_id", response.headers["x-ores-middleware-chain"]
    assert_equal ["/inventory/demo-product", "/products/demo-product"], calls.sort

    payload = JSON.parse(response.body)
    assert_equal "products/show#show", payload.fetch("controller_execution")
    assert_equal "/products/demo-product", payload.fetch("path")
    assert_equal "/inventory/demo-product", payload.fetch("inventory").fetch("path")
  end
end
