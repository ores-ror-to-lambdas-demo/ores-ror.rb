# frozen_string_literal: true

OresApp::Routes.register(
  verb: "POST",
  name: "checkout_session",
  group: "checkout",
  pool: "checkout",
  source: "routes/checkout-sessions/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandler.safe_id(request)
  OresApp::RouteHandler.proxy(:post, "/checkout-sessions/#{id}", body: request["body"])
end
