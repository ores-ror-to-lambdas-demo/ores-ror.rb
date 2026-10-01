# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET", name: "health", handler: "health", group: "system", pool: "system",
  source: "routes/healthz/handler.rb"
) do |request|
  OresApp::RouteHandlers.health(request)
end
