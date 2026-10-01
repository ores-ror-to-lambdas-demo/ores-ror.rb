# frozen_string_literal: true

require "json"
require "minitest/autorun"
require_relative "../aws-lambda/handler"

class AwsLambdaAdapterTest < Minitest::Test
  def test_http_api_v2_event_reaches_generated_route_handler_without_rails
    refute defined?(Rails), "lambda test must not load Rails"

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
    assert_equal "lambda", payload.fetch("execution_mode")
    refute defined?(Rails), "lambda invocation must not load Rails"
  end
end
