# frozen_string_literal: true

require "json"
require_relative "../aws-lambda/adapter"

def assert(condition, message)
  raise message unless condition
end

assert(!defined?(Rails), "lambda test must not load Rails")

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
assert(response.fetch("statusCode") == 200, "expected 200 from Lambda adapter")
assert(response.fetch("isBase64Encoded") == false, "health response should be textual")

payload = JSON.parse(response.fetch("body"))
assert(payload.fetch("ok") == true, "health payload must be ok")
assert(payload.fetch("service") == "ores-ror.rb", "wrong service")
assert(payload.fetch("execution_mode") == "lambda", "wrong execution mode")
assert(!defined?(Rails), "lambda invocation must not load Rails")

puts JSON.generate(response)
