require "json"

SAFE_ID = /\A[A-Za-z0-9_-]{1,128}\z/

ROUTES = {
  "users.show" => ["GET", "/users/%{id}"],
  "carts.show" => ["GET", "/carts/%{id}"],
  "checkout_sessions.create" => ["POST", "/checkout-sessions/%{id}"],
  "products.show" => ["GET", "/products/%{id}"],
  "orders.show" => ["GET", "/orders/%{id}"],
  "orders.cancel" => ["POST", "/orders/%{id}/cancel"],
  "accounts.show" => ["GET", "/accounts/%{id}"],
  "inventory.show" => ["GET", "/inventory/%{id}"],
  "recommendations.show" => ["GET", "/recommendations/%{id}"],
  "search.index" => ["GET", "/search"],
  "sessions.create" => ["POST", "/sessions"],
  "preferences.show" => ["GET", "/profiles/%{id}/preferences"],
  "health.show" => ["LOCAL", "/healthz"]
}.freeze

def pct(value)
  value.to_s.bytes.map do |byte|
    char = byte.chr
    char.match?(/[A-Za-z0-9_.~-]/) ? char : format("%%%02X", byte)
  end.join
end

def build_query(query)
  return "" unless query.is_a?(Hash) && !query.empty?
  "?" + query.sort.map { |key, value| "#{pct(key)}=#{pct(value)}" }.join("&")
end

def handler(request_json)
  request = JSON.parse(request_json)
  request_id = request.fetch("request_id")
  route = request.fetch("route")
  spec = ROUTES.fetch(route)

  if spec[0] == "LOCAL"
    return JSON.generate({ok: true, request_id: request_id, status: 200, body: {ok: true, service: "ores-ror.rb"}})
  end

  params = request.fetch("params", {})
  path = spec[1]
  if path.include?("%{id}")
    id = params.fetch("id").to_s
    raise ArgumentError, "invalid id" unless id.match?(SAFE_ID)
    path = path % {id: id}
  end

  base_url = request.fetch("data_api_base_url").sub(%r{/\z}, "")
  query = build_query(request.fetch("query", {}))
  outbound = {
    method: spec[0],
    url: "#{base_url}#{path}#{query}",
    headers: {"accept" => "application/json", "content-type" => "application/json"},
    timeout_ms: 10_000
  }
  outbound[:body] = JSON.generate(request["body"]) if request.key?("body") && !request["body"].nil?

  response = JSON.parse(gs_http(JSON.generate(outbound)))
  raise "data API request failed" unless response["ok"]

  body = response["body"].to_s.empty? ? {} : JSON.parse(response["body"])
  JSON.generate({
    ok: true,
    request_id: request_id,
    status: response.fetch("status"),
    body: body
  })
rescue => error
  JSON.generate({
    ok: false,
    request_id: (defined?(request_id) ? request_id : nil),
    status: 500,
    error: error.message.to_s[0, 512]
  })
end
