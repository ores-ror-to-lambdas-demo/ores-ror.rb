# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET", name: "cart", handler: "cart", group: "carts", pool: "carts",
  source: "routes/carts/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandlers.safe_id(request)
  OresApp::RouteHandlers.proxy(:get, "/carts/#{id}")
end
