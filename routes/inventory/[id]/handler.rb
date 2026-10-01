# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET", name: "inventory", handler: "inventory", group: "inventory", pool: "inventory",
  source: "routes/inventory/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandlers.safe_id(request)
  OresApp::RouteHandlers.proxy(:get, "/inventory/#{id}")
end
