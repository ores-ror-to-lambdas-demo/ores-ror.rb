# frozen_string_literal: true

require "json"
require "uri"
require_relative "routes"
require_relative "middleware"
require_relative "route_handlers"

module OresApp
  module Dispatcher
    module_function

    def call(raw_request, invoker: nil)
      request = normalize_request(raw_request)
      match = Routes.match(request.fetch("method"), request.fetch("path"))
      return serialize_response(status: 404, headers: {}, body: { error: "route not found" }) unless match

      route, path_params = match
      request["path_params"] = path_params
      request["route_name"] = route.name
      request["route_group"] = route.group
      request["isolate_pool"] = route.pool

      result = Middleware.call(route.middleware, request) do
        if invoker
          invoker.call(route, request)
        else
          RouteHandlers.call(route, request)
        end
      end

      serialize_response(result)
    rescue ArgumentError, KeyError => error
      serialize_response(status: 400, headers: {}, body: { error: error.message })
    rescue HttpDatabase::Error => error
      serialize_response(status: 502, headers: {}, body: { error: error.message })
    end

    def normalize_request(raw_request)
      request = stringify_keys(raw_request || {})
      headers = stringify_keys(request["headers"] || {}).transform_keys(&:downcase)
      query = stringify_keys(request["query"] || parse_query_string(request["query_string"]))
      content_type = request["content_type"].to_s
      content_type = headers["content-type"].to_s if content_type.empty?

      {
        "request_id" => request["request_id"] || headers["x-request-id"],
        "method" => request.fetch("method", "GET").to_s.upcase,
        "path" => request.fetch("path", "/").to_s,
        "headers" => headers,
        "query" => query,
        "body" => normalize_body(request["body"], content_type)
      }
    end

    def normalize_body(body, content_type)
      return body unless body.is_a?(String)
      return nil if body.empty?
      return body unless content_type.downcase.include?("json")

      JSON.parse(body)
    rescue JSON::ParserError => error
      raise ArgumentError, "invalid JSON body: #{error.message}"
    end

    def parse_query_string(query_string)
      return {} if query_string.nil? || query_string.to_s.empty?

      URI.decode_www_form(query_string.to_s).each_with_object({}) do |(key, value), out|
        if out.key?(key)
          out[key] = Array(out[key]) << value
        else
          out[key] = value
        end
      end
    end

    def serialize_response(result)
      status = result.fetch(:status)
      headers = stringify_keys(result.fetch(:headers, {})).transform_keys(&:downcase)
      headers["content-type"] ||= "application/json; charset=utf-8"
      body = result[:body]
      body = JSON.generate(body) unless body.is_a?(String)

      {
        "status" => Integer(status),
        "headers" => headers,
        "body" => body
      }
    end

    def stringify_keys(value)
      return value.transform_keys(&:to_s).transform_values { |entry| stringify_keys(entry) } if value.is_a?(Hash)
      return value.map { |entry| stringify_keys(entry) } if value.is_a?(Array)

      value
    end
    private_class_method :normalize_request, :normalize_body, :parse_query_string, :serialize_response, :stringify_keys
  end
end
