require "test_helper"

class RuntimeContractTest < ActionDispatch::IntegrationTest
  test "health runs through Rails but shared runtime core owns behavior" do
    get "/healthz", headers: { "x-request-id" => "contract-health" }
    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal true, payload.fetch("ok")
    assert_equal "ores-ror.rb", payload.fetch("service")
    assert payload.fetch("runtime").is_a?(String)
    assert payload.fetch("request_id").is_a?(String)
  end

  test "Rails routes adapt the shared route table to one dispatch action" do
    assert_recognizes(
      { controller: "resources", action: "dispatch", id: "demo-user" },
      { path: "/users/demo-user", method: :get }
    )
    assert_recognizes(
      { controller: "resources", action: "dispatch", id: "cart-1" },
      { path: "/checkout-sessions/cart-1", method: :post }
    )
  end
end
