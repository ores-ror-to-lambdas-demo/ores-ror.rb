# frozen_string_literal: true

require "json"
require_relative "../lib/ores_build/static_routes"
require_relative "../test/support/route_contract"

output = ARGV.fetch(0)
root = Rails.root.to_s
routes = OresBuild::StaticRoutes.new(root).compile
raise "expected at least 15 routes" if routes.length < 15

OresApp::HttpDatabase.define_singleton_method(:request) do |method, path, body: nil, query: {}|
  RouteContract.database_response(method: method, path: path, query: query, body: body)
end

session = ActionDispatch::Integration::Session.new(Rails.application)
rows = []

routes.each do |route|
  %w[json html].each do |format|
    request = RouteContract.request_for(route, format)
    headers = {
      "Accept" => request.fetch("headers").fetch("accept"),
      "X-Request-Id" => request.fetch("request_id")
    }

    if request["body"]
      headers["Content-Type"] = "application/json"
      session.public_send(
        request.fetch("method").downcase,
        request.fetch("path"),
        params: JSON.generate(request.fetch("body")),
        headers: headers
      )
    else
      session.public_send(
        request.fetch("method").downcase,
        request.fetch("path"),
        params: request.fetch("query"),
        headers: headers
      )
    end

    rows << RouteContract.canonical_result(
      route: route,
      format: format,
      status: session.response.status,
      content_type: session.response.media_type,
      body: session.response.body
    )
  end
end

File.write(output, JSON.pretty_generate(rows) + "\n")
