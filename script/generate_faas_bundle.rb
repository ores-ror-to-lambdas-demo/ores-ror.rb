#!/usr/bin/env ruby
require "fileutils"
require "json"

ROOT = File.expand_path("..", __dir__)
TARGET = ENV.fetch("ORES_BUILD_TARGET", ARGV.first || "graal")
OUT_ROOT = File.join(ROOT, ".ores-generated", TARGET)

require File.join(ROOT, "lib", "ores_app", "routes")

FileUtils.mkdir_p(OUT_ROOT)

manifest = OresApp::Routes::ROUTES.map do |route|
  {
    method: route.method,
    path: route.path,
    name: route.name,
    backend_path: route.backend_path,
    forward_query: !!route.forward_query,
    forward_body: !!route.forward_body,
    health: !!route.health
  }
end

File.write(File.join(OUT_ROOT, "routes.json"), JSON.pretty_generate(manifest) + "\n")

if TARGET == "graal"
  source_paths = [
    "lib/ores_app/routes.rb",
    "lib/ores_app/middleware.rb",
    "app/services/http_database.rb",
    "lib/ores_runtime/core_dispatch.rb",
    "graal/bootstrap.rb"
  ]

  prelude = <<~RUBY
    # generated; do not edit or commit
    ORES_GRAAL_RUNTIME = true unless defined?(ORES_GRAAL_RUNTIME)
    ORES_GS_HTTP = method(:gs_http) unless defined?(ORES_GS_HTTP)
  RUBY

  body = source_paths.map do |relative|
    "\n# --- #{relative} ---\n#{File.read(File.join(ROOT, relative))}\n"
  end.join

  File.write(File.join(OUT_ROOT, "handler.rb"), prelude + body)
end

puts "generated #{TARGET} runtime metadata at #{OUT_ROOT}"
