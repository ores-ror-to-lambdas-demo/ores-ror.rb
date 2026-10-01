# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET", name: "recommendations", handler: "recommendations", group: "recommendations", pool: "recommendations",
  source: "routes/recommendations/[id]/handler.rb"
) do |request|
  id = OresApp::RouteHandlers.safe_id(request)
  OresApp::RouteHandlers.proxy(:get, "/recommendations/#{id}", query: request["query"])
end
