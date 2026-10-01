# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET",
  name: "recommendations",
  group: "recommendations",
  pool: "recommendations",
  source: "routes/recommendations/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandler.safe_id(request)
  OresApp::RouteHandler.proxy(:get, "/recommendations/#{id}", query: request["query"])
end
