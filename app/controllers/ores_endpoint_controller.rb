# frozen_string_literal: true

require "json"
require_relative "../../lib/ores_app/dispatcher"

class OresEndpointController < ApplicationController
  # Dual-runtime endpoints must share one middleware/security contract with
  # Rails-free Graal/Lambda. Do not let Rails-only CSRF interception create
  # behavior that the generated runtime cannot reproduce.
  skip_forgery_protection

  private

  def dispatch_ores_endpoint
    route_middleware = request.path_parameters[:ores_middleware] || request.path_parameters["ores_middleware"] || OresApp::Routes::DEFAULT_MIDDLEWARE
    path_params = request.path_parameters.to_h.reject do |key, _|
      %w[controller action ores_middleware].include?(key.to_s)
    end

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
      action: action_name,
      middleware: route_middleware
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
    raw = request.raw_post.to_s
    return nil if raw.empty?
    return JSON.parse(raw) if request.content_type.to_s.include?("json")

    raw
  rescue JSON::ParserError => error
    raise ActionController::BadRequest, "invalid JSON body: #{error.message}"
  end
end
