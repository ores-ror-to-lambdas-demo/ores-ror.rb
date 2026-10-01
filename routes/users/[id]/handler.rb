# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET",
  name: "user",
  group: "users",
  pool: "users",
  source: "routes/users/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandler.safe_id(request)
  OresApp::RouteHandler.proxy(:get, "/users/#{id}")
end
