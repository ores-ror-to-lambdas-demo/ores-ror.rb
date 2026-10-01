# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET", name: "preferences", handler: "preferences", group: "profiles", pool: "profiles",
  source: "routes/profiles/[id]/preferences/handler.rb"
) do |request|
  id = OresApp::RouteHandlers.safe_id(request)
  OresApp::RouteHandlers.proxy(:get, "/profiles/#{id}/preferences")
end
