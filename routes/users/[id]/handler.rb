# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET", name: "user", handler: "user", group: "users", pool: "users",
  source: "routes/users/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandlers.safe_id(request)
  OresApp::RouteHandlers.proxy(:get, "/users/#{id}")
end
