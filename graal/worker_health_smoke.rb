#!/usr/bin/env truffleruby
# frozen_string_literal: true

require "json"
require_relative "worker_cluster"

app_root = File.expand_path("..", __dir__)
bridge = lambda do |_raw_json|
  JSON.generate("ok" => false, "error" => "health smoke must not use data bridge")
end
cluster = OresGraal::WorkerCluster.new(
  app_root: app_root,
  contexts_per_handler: 1,
  host_http_bridge: bridge
)

begin
  response = cluster.call(
    "request_id" => "worker-health-smoke",
    "method" => "GET",
    "path" => "/healthz",
    "headers" => { "x-request-id" => "worker-health-smoke" }
  )
  raise "unexpected status: #{response.inspect}" unless response.fetch("status") == 200
  raise "wrong worker model" unless response.fetch("headers").fetch("x-ores-worker-model") == "graal-inner-context"
  raise "wrong pool" unless response.fetch("headers").fetch("x-ores-worker-pool") == "routes/healthz/handler.rb"
  raise "wrong execution mode: #{response.inspect}" unless response.fetch("body").include?('"execution_mode":"graal-context"')
  puts JSON.generate(response)
  puts "graal direct worker health smoke: ok"
ensure
  cluster.close
end
