# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET", name: "order", handler: "order", group: "orders", pool: "orders",
  source: "routes/orders/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandlers.safe_id(request)
  OresApp::RouteHandlers.proxy(:get, "/orders/#{id}")
end
