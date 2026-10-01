# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET", name: "account", handler: "account", group: "accounts", pool: "accounts",
  source: "routes/accounts/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandlers.safe_id(request)
  OresApp::RouteHandlers.proxy(:get, "/accounts/#{id}")
end
