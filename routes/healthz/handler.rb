# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET",
  name: "health",
  group: "system",
  pool: "system",
  source: "routes/healthz/handler.rb"
) do |request|
  OresApp::RouteHandler.health(request)
end
