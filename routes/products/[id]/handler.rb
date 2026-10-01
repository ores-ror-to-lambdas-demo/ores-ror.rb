# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET",
  name: "product",
  group: "products",
  pool: "products",
  source: "routes/products/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandler.safe_id(request)
  OresApp::RouteHandler.proxy(:get, "/products/#{id}")
end
