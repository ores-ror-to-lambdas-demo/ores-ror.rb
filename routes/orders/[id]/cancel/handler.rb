# frozen_string_literal: true

OresApp::Routes.register(
  verb: "POST", name: "cancel_order", handler: "cancel_order", group: "orders", pool: "orders",
  source: "routes/orders/[id]/cancel/handler.rb"
) do |request|
  id = OresApp::RouteHandlers.safe_id(request)
  OresApp::RouteHandlers.proxy(:post, "/orders/#{id}/cancel", body: request["body"])
end
