# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET",
  name: "account",
  group: "accounts",
  pool: "accounts",
  source: "routes/accounts/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandler.safe_id(request)
  OresApp::RouteHandler.proxy(:get, "/accounts/#{id}")
end
