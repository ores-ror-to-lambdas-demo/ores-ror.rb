# frozen_string_literal: true

OresApp::Routes.register(
  verb: "GET", name: "search", handler: "search", group: "search", pool: "search",
  source: "routes/search/handler.rb"
) do |request|
  OresApp::RouteHandlers.proxy(:get, "/search", query: request["query"])
end
