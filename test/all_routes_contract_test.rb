# frozen_string_literal: true

require "test_helper"
require "cgi"
require "minitest/mock"
require Rails.root.join("lib/ores_build/static_routes")
require Rails.root.join("test/support/route_contract")

class AllRoutesContractTest < ActionDispatch::IntegrationTest
  test "every route works as both json and html with the same model payload" do
    routes = OresBuild::StaticRoutes.new(Rails.root).compile
    assert_operator routes.length, :>=, 15

    mock = lambda do |method, path, body: nil, query: {}|
      RouteContract.database_response(method: method, path: path, query: query, body: body)
    end

    OresApp::HttpDatabase.stub(:request, mock) do
      routes.each do |route|
        %w[json html].each do |format|
          request = RouteContract.request_for(route, format)
          headers = {
            "Accept" => request.fetch("headers").fetch("accept"),
            "X-Request-Id" => request.fetch("request_id")
          }

          if request["body"]
            headers["Content-Type"] = "application/json"
            public_send(
              request.fetch("method").downcase,
              request.fetch("path"),
              params: JSON.generate(request.fetch("body")),
              headers: headers
            )
          else
            public_send(
              request.fetch("method").downcase,
              request.fetch("path"),
              params: request.fetch("query"),
              headers: headers
            )
          end

          assert_response :success, "#{route.fetch(:name)} #{format}: #{response.body}"
          expected_type = format == "html" ? "text/html" : "application/json"
          assert_equal expected_type, response.media_type, route.inspect

          result = RouteContract.canonical_result(
            route: route,
            format: format,
            status: response.status,
            content_type: response.media_type,
            body: response.body
          )
          assert_equal 200, result.fetch("status")
        end
      end
    end
  end
end
