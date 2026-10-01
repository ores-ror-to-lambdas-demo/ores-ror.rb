# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET",
  name: "inventory",
  group: "inventory",
  pool: "inventory",
  source: "routes/inventory/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandler.safe_id(request)
  OresApp::RouteHandler.proxy(:get, "/inventory/#{id}")
end
