# frozen_string_literal: true

require_relative "../../lib/ores_app/dispatcher"

class OresEndpointController < ApplicationController
  private

  def dispatch_ores_endpoint(expected_route_name:)
    result = OresApp::Dispatcher.call({
      "request_id" => request.request_id,
      "method" => request.request_method,
      "path" => request.path,
      "query" => request.query_parameters,
      "headers" => request.headers.to_h.select { |name, _| %w[content-type x-request-id].include?(name.to_s.downcase) },
      "content_type" => request.content_type,
      "body" => parsed_body
    })

    matched = OresApp::Routes.match(request.request_method, request.path)
    if matched && matched.first.name != expected_route_name
      raise "endpoint controller mismatch: expected #{expected_route_name}, matched #{matched.first.name}"
    end

    result.fetch("headers", {}).each { |name, value| response.set_header(name, value) }
    self.status = result.fetch("status")
    self.response_body = result.fetch("body")
  end

  def parsed_body
    return nil if request.raw_post.to_s.empty?
    return request.request_parameters if request.content_type.to_s.include?("json")

    request.raw_post
  end
end
