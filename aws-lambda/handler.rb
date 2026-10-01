require "base64"
require "uri"
require_relative "../config/environment"
require_relative "../lib/ores_runtime/rack_dispatch"

module OresRuntime
  module AwsLambda
    module_function

    def handle(event, request_id: nil)
      request = event_to_request(event, request_id: request_id)
      rack = RackDispatch.call(Rails.application, request)
      content_type = rack.fetch("headers", {}).fetch("content-type", "application/octet-stream")
      body = rack.fetch("body", "")
      textual = RackDispatch.textual_media_type?(content_type)

      response_headers = rack.fetch("headers").dup
      response_headers.delete("content-length")
      response_headers.delete("transfer-encoding")
      response_headers.delete("connection")

      {
        "statusCode" => rack.fetch("status"),
        "headers" => response_headers,
        "body" => textual ? body : Base64.strict_encode64(body),
        "isBase64Encoded" => !textual
      }
    end

    def event_to_request(event, request_id: nil)
      version = event["version"].to_s
      if version == "2.0" || event.dig("requestContext", "http")
        from_v2(event, request_id: request_id)
      else
        from_v1(event, request_id: request_id)
      end
    end

    def from_v2(event, request_id:)
      body = decode_body(event)
      headers = event.fetch("headers", {}).dup
      cookies = Array(event["cookies"])
      headers["cookie"] = cookies.join("; ") unless cookies.empty?
      {
        "request_id" => request_id || event.dig("requestContext", "requestId") || "aws-lambda",
        "method" => event.dig("requestContext", "http", "method") || "GET",
        "path" => event["rawPath"] || event.dig("requestContext", "http", "path") || "/",
        "query_string" => event.fetch("rawQueryString", ""),
        "headers" => headers,
        "body" => body
      }
    end

    def from_v1(event, request_id:)
      query = event["multiValueQueryStringParameters"] || event["queryStringParameters"] || {}
      pairs = []
      query.each do |key, value|
        Array(value).each do |entry|
          pairs << "#{URI.encode_www_form_component(key.to_s)}=#{URI.encode_www_form_component(entry.to_s)}"
        end
      end
      {
        "request_id" => request_id || event.dig("requestContext", "requestId") || "aws-lambda",
        "method" => event.fetch("httpMethod", "GET"),
        "path" => event["path"] || "/",
        "query_string" => pairs.join("&"),
        "headers" => event.fetch("headers", {}),
        "body" => decode_body(event)
      }
    end

    def decode_body(event)
      raw = event["body"].to_s
      event["isBase64Encoded"] ? Base64.decode64(raw) : raw
    end
  end
end
