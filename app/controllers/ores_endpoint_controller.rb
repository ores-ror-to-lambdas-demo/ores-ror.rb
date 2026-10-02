# frozen_string_literal: true

require "json"
require_relative "../../lib/ores_app/dispatcher"

class OresEndpointController < ApplicationController
  private

  def dispatch_ores_endpoint
    path_params = request.path_parameters.to_h.reject { |key, _| %w[controller action].include?(key.to_s) }

    result = OresApp::Dispatcher.call_direct(
      {
        "request_id" => request.request_id,
        "method" => request.request_method,
        "path" => request.path,
        "query" => request.query_parameters,
        "headers" => request.headers.to_h.select { |name, _| %w[accept content-type x-request-id].include?(name.to_s.downcase) },
        "content_type" => request.content_type,
        "body" => parsed_body,
        "path_params" => path_params
      },
      controller_path: self.class.controller_path,
      action: action_name
    )

    result.fetch("headers", {}).each do |name, value|
      next if %w[content-length content-type].include?(name.to_s.downcase)
      response.set_header(name, value)
    end

    payload = result.fetch("body")
    payload = JSON.parse(payload) if payload.is_a?(String)
    model = endpoint_model_class.new(payload)

    format = request.headers["Accept"].to_s.downcase.include?("text/html") ? :html : :json
    render(
      template: "#{self.class.controller_path}/#{action_name}",
      formats: [format],
      locals: { model: model },
      status: result.fetch("status")
    )
  end

  def endpoint_model_class
    resource = self.class.controller_path.split("/").first
    singular = resource.singularize
    token = singular == resource ? "#{resource}_record" : singular
    token.camelize.constantize
  end

  def parsed_body
    return nil if request.raw_post.to_s.empty?
    return request.request_parameters if request.content_type.to_s.include?("json")

    request.raw_post
  end
end
