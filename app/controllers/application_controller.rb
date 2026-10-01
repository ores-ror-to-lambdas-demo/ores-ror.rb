# frozen_string_literal: true

require_relative "../../lib/ores_app/dispatcher"

class ApplicationController < ActionController::API
  rescue_from OresApp::HttpDatabase::Error do |error|
    render json: { ok: false, error: error.message }, status: :bad_gateway
  end

  private

  def dispatch_ores
    result = OresApp::Dispatcher.call(
      "request_id" => request.request_id,
      "method" => request.request_method,
      "path" => request.path,
      "query" => request.query_parameters,
      "headers" => request.headers.to_h.select { |name, _| %w[content-type x-request-id].include?(name.to_s.downcase) },
      "content_type" => request.content_type,
      "body" => parsed_ores_body
    )

    result.fetch("headers", {}).each do |name, value|
      response.set_header(name, value)
    end
    self.status = result.fetch("status")
    self.response_body = result.fetch("body")
  end

  def parsed_ores_body
    return nil if request.raw_post.to_s.empty?
    return request.request_parameters if request.content_type.to_s.include?("json")

    request.raw_post
  end
end
