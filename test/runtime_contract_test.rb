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

  test "resource routes use the shared HttpDatabase service" do
    fake = ->(method, path, body: nil, query: {}) {
      { status: 200, body: { "method" => method.to_s, "path" => path, "body" => body, "query" => query } }
    }

    HttpDatabase.stub(:request, fake) do
      get "/users/demo-user"
      assert_response :success
      assert_equal "/users/demo-user", JSON.parse(response.body).fetch("path")
    end
  end
end
