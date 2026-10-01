require "test_helper"
require_relative "../aws-lambda/handler"

class AwsLambdaAdapterTest < ActiveSupport::TestCase
  test "HTTP API v2 event reaches the same Rails health route" do
    event = {
      "version" => "2.0",
      "rawPath" => "/healthz",
      "rawQueryString" => "",
      "headers" => { "accept" => "application/json" },
      "requestContext" => {
        "requestId" => "lambda-test-event",
        "http" => { "method" => "GET", "path" => "/healthz" }
      },
      "isBase64Encoded" => false
    }

    response = OresRuntime::AwsLambda.handle(event, request_id: "lambda-runtime-request")
    assert_equal 200, response.fetch("statusCode")
    assert_equal false, response.fetch("isBase64Encoded")
    payload = JSON.parse(response.fetch("body"))
    assert_equal true, payload.fetch("ok")
    assert_equal "ores-ror.rb", payload.fetch("service")
  end
end
