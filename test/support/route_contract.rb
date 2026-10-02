# frozen_string_literal: true

require "cgi"
require "json"

module RouteContract
  ACCEPT = {
    "json" => "application/json",
    "html" => "text/html"
  }.freeze

  ROUTE_POLICY = {
    "user" => "users-show",
    "cancel_order" => "order-cancel",
    "search" => "search"
  }.freeze

  module_function

  def stringify(value)
    case value
    when Hash
      value.each_with_object({}) { |(key, entry), out| out[key.to_s] = stringify(entry) }
    when Array
      value.map { |entry| stringify(entry) }
    else
      value
    end
  end

  def request_for(route, format)
    route = stringify(route)
    path = route.fetch("path").gsub(/:([A-Za-z_][A-Za-z0-9_]*)/) { "demo-#{$1}" }
    query = case route.fetch("name")
            when "search" then { "q" => "routing-parity" }
            when "recommendations", "user_activity" then { "limit" => "3" }
            else {}
            end
    body = if %w[POST PUT PATCH DELETE].include?(route.fetch("verb"))
             { "sample" => "payload", "route" => route.fetch("name") }
           end

    {
      "request_id" => "contract-#{route.fetch("name")}",
      "method" => route.fetch("verb"),
      "path" => path,
      "query" => query,
      "headers" => {
        "accept" => ACCEPT.fetch(format),
        "content-type" => "application/json",
        "x-request-id" => "contract-#{route.fetch("name")}"
      },
      "content_type" => "application/json",
      "body" => body
    }
  end

  def database_response(method:, path:, query:, body:)
    {
      status: 200,
      body: {
        "ok" => true,
        "method" => method.to_s.upcase,
        "path" => path.to_s,
        "query" => stringify(query || {}),
        "body" => stringify(body)
      }
    }
  end

  def expected_payload(route, request)
    route = stringify(route)
    request = stringify(request)
    if route.fetch("name") == "health"
      {
        "ok" => true,
        "service" => "ores-ror.rb",
        "request_id" => request.fetch("request_id")
      }
    else
      database_response(
        method: request.fetch("method"),
        path: request.fetch("path"),
        query: request.fetch("query"),
        body: request["body"]
      ).fetch(:body)
    end
  end

  def extract_payload(format, body)
    if format == "json"
      JSON.parse(body)
    else
      match = body.match(/<pre data-ores-payload>(.*?)<\/pre>/m)
      raise "HTML response is missing data-ores-payload" unless match
      JSON.parse(CGI.unescapeHTML(match[1]))
    end
  end

  def middleware_names(route)
    route = stringify(route)
    value = route.fetch("middleware")
    value.is_a?(String) ? value.split(",").map(&:strip) : Array(value).map(&:to_s)
  end

  def expected_middleware_headers(route)
    route = stringify(route)
    headers = {
      "x-request-id" => "contract-#{route.fetch("name")}",
      "x-ores-middleware-chain" => middleware_names(route).join(",")
    }
    policy = ROUTE_POLICY[route.fetch("name")]
    headers["x-ores-route-policy"] = policy if policy
    headers
  end

  def canonical_result(route:, format:, status:, content_type:, headers:, body:)
    route = stringify(route)
    request = request_for(route, format)
    payload = extract_payload(format, body)
    expected = expected_payload(route, request)
    raise "#{route.fetch("name")} #{format} payload mismatch: #{payload.inspect} != #{expected.inspect}" unless payload == expected

    response_headers = stringify(headers || {}).transform_keys(&:downcase)
    middleware_headers = response_headers.select do |name, _|
      %w[x-request-id x-ores-middleware-chain x-ores-route-policy].include?(name)
    end
    expected_headers = expected_middleware_headers(route)
    unless middleware_headers == expected_headers
      raise "#{route.fetch("name")} #{format} middleware headers mismatch: #{middleware_headers.inspect} != #{expected_headers.inspect}"
    end

    {
      "name" => route.fetch("name"),
      "verb" => route.fetch("verb"),
      "path" => route.fetch("path"),
      "format" => format,
      "middleware" => middleware_names(route),
      "middleware_headers" => middleware_headers,
      "status" => Integer(status),
      "content_type" => content_type.to_s.split(";").first,
      "payload" => payload,
      "body" => body
    }
  end
end
