# frozen_string_literal: true

OresApp::Routes.register(
  verb: "POST", name: "sessions", handler: "create_session", group: "sessions", pool: "sessions",
  source: "routes/sessions/handler.rb"
) do |request|
  OresApp::RouteHandlers.proxy(:post, "/sessions", body: request["body"])
end
