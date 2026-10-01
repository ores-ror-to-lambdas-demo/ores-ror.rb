require Rails.root.join("lib", "ores_app", "routes")
require Rails.root.join("lib", "ores_app", "middleware")
require Rails.root.join("lib", "ores_runtime", "core_dispatch")
require Rails.root.join("app", "services", "http_database")

class ResourcesController < ApplicationController
  def dispatch
    result = OresRuntime::CoreDispatch.call(
      "request_id" => request.request_id,
      "method" => request.request_method,
      "path" => request.path,
      "query_string" => request.query_string.to_s,
      "headers" => {
        "content-type" => request.content_type,
        "accept" => request.headers["accept"]
      }.compact,
      "body" => request.raw_post.to_s
    )

    result.fetch("headers", {}).each do |name, value|
      response.set_header(name, value)
    end

    render plain: result.fetch("body", ""),
      status: result.fetch("status", 500),
      content_type: result.dig("headers", "content-type") || "application/json"
  end
end
