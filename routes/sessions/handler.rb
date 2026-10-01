# frozen_string_literal: true

OresApp::Routes.register(
  verb: "POST",
  name: "sessions",
  group: "sessions",
  pool: "sessions",
  source: "routes/sessions/handler.rb"
) do |request|
  OresApp::RouteHandler.proxy(:post, "/sessions", body: request["body"])
end
