ORES_GRAAL_RUNTIME = true unless defined?(ORES_GRAAL_RUNTIME)
ORES_GS_HTTP = method(:gs_http) unless defined?(ORES_GS_HTTP)

app_root = gs_app_root.to_s
rails_env = gs_rails_env.to_s
ENV["BUNDLE_GEMFILE"] = File.join(app_root, "Gemfile")
ENV["RAILS_ENV"] = rails_env
ENV["RACK_ENV"] = rails_env
ENV["RAILS_LOG_TO_STDOUT"] = "1"

require "json"
require "rack/mock"
require File.join(app_root, "config", "environment")

Rails.application.eager_load!
ORES_RAILS_APP = Rails.application unless defined?(ORES_RAILS_APP)

def ores_rack_invoke(request_json)
  request = JSON.parse(request_json)
  path = request.fetch("path")
  query = request.fetch("query_string", "").to_s
  target = query.empty? ? path : "#{path}?#{query}"
  input = request.fetch("body", "").to_s
  content_type = request.fetch("content_type", "application/json").to_s

  env = Rack::MockRequest.env_for(
    target,
    method: request.fetch("method"),
    input: input,
    "CONTENT_TYPE" => content_type,
    "HTTP_X_REQUEST_ID" => request.fetch("request_id")
  )

  status, headers, body = ORES_RAILS_APP.call(env)
  chunks = []
  begin
    body.each { |chunk| chunks << chunk.to_s }
  ensure
    body.close if body.respond_to?(:close)
  end

  JSON.generate(status: status, headers: headers, body: chunks.join)
end

method(:ores_rack_invoke)
