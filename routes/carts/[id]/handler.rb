# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET",
  name: "cart",
  group: "carts",
  pool: "carts",
  source: "routes/carts/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandler.safe_id(request)
  OresApp::RouteHandler.proxy(:get, "/carts/#{id}")
end
