# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET", name: "product", handler: "product", group: "products", pool: "products",
  source: "routes/products/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandlers.safe_id(request)
  OresApp::RouteHandlers.proxy(:get, "/products/#{id}")
end
