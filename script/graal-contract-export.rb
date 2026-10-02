# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"
require_relative "../test/support/route_contract"

ROOT = File.expand_path("..", __dir__)
MANIFEST = JSON.parse(File.read(File.join(ROOT, "generated/graal/manifest.json")))

def route_unit_for(route_id)
  unit = MANIFEST.fetch("isolate_units").find do |entry|
    entry.fetch("kind") == "route" && entry.fetch("route_ids") == [route_id]
  end
  raise "missing route unit for #{route_id}" unless unit
  unit.fetch("sources").find { |source| source != "generated/graal/common.rb" }
end

def run_case(route)
  common = File.read(File.join(ROOT, "generated/graal/common.rb"))
  unit_relative = route_unit_for(route.fetch("route_id"))
  unit_path = File.join(ROOT, unit_relative)
  raise "Rails unexpectedly loaded before Graal unit" if defined?(Rails)

  eval(common, TOPLEVEL_BINDING, "generated/graal/common.rb")
  factory = eval(File.read(unit_path), TOPLEVEL_BINDING, unit_relative)
  raise "generated unit did not return a factory" unless factory.respond_to?(:call)

  host_http = lambda do |payload|
    request = JSON.parse(payload.to_s)
    result = RouteContract.database_response(
      method: request.fetch("method"),
      path: request.fetch("path"),
      query: request.fetch("query", {}),
      body: request["body"]
    )
    JSON.generate(
      "ok" => true,
      "status" => result.fetch(:status),
      "body" => JSON.generate(result.fetch(:body))
    )
  end

  invoker = factory.call(host_http)
  raise "generated unit did not return an invoker" unless invoker.respond_to?(:call)
  raise "Rails unexpectedly loaded in Graal route unit" if defined?(Rails)
  raise "ActionController unexpectedly loaded in Graal route unit" if defined?(ActionController)
  raise "ActionView unexpectedly loaded in Graal route unit" if defined?(ActionView)

  %w[json html].map do |format|
    request = RouteContract.request_for(route, format)
    response = JSON.parse(invoker.call(JSON.generate(request)))
    RouteContract.canonical_result(
      route: route,
      format: format,
      status: response.fetch("status"),
      content_type: response.fetch("headers").fetch("content-type"),
      headers: response.fetch("headers"),
      body: response.fetch("body")
    )
  end
end

if ARGV.first == "--case"
  route_id = ARGV.fetch(1)
  route = MANIFEST.fetch("routes").find { |entry| entry.fetch("route_id") == route_id }
  raise "unknown route id #{route_id}" unless route
  puts JSON.generate(run_case(route))
  exit
end

output = ARGV.fetch(0)
routes = MANIFEST.fetch("routes")
raise "expected at least 15 routes" if routes.length < 15
rows = routes.flat_map do |route|
  stdout, stderr, status = Open3.capture3(
    { "ORES_BUILD_TARGET" => "graal" },
    RbConfig.ruby,
    __FILE__,
    "--case",
    route.fetch("route_id")
  )
  raise "Graal route #{route.fetch("name")} failed: #{stderr}\n#{stdout}" unless status.success?
  JSON.parse(stdout)
end

File.write(output, JSON.pretty_generate(rows) + "\n")
