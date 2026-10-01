# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET",
  name: "preferences",
  group: "profiles",
  pool: "profiles",
  source: "routes/profiles/[id]/preferences/handler.rb"
) do |request|
  id = OresApp::RouteHandler.safe_id(request)
  OresApp::RouteHandler.proxy(:get, "/profiles/#{id}/preferences")
end
