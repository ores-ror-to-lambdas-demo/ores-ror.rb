# frozen_string_literal: true

OresApp::Routes.register(
  verb: "POST",
  name: "cancel_order",
  group: "orders",
  pool: "orders",
  source: "routes/orders/[id]/cancel/handler.rb"
) do |request|
  id = OresApp::RouteHandler.safe_id(request)
  OresApp::RouteHandler.proxy(:post, "/orders/#{id}/cancel", body: request["body"])
end
