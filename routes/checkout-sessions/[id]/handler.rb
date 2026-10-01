# frozen_string_literal: true

OresApp::Routes.register(
  verb: "POST", name: "checkout_session", handler: "checkout_session", group: "checkout", pool: "checkout",
  source: "routes/checkout-sessions/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandlers.safe_id(request)
  OresApp::RouteHandlers.proxy(:post, "/checkout-sessions/#{id}", body: request["body"])
end
