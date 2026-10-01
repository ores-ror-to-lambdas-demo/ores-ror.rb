# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET",
  name: "order",
  group: "orders",
  pool: "orders",
  source: "routes/orders/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandler.safe_id(request)
  OresApp::RouteHandler.proxy(:get, "/orders/#{id}")
end
