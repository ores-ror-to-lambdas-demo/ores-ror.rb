# frozen_string_literal: true

require "json"
require_relative "application_controller"
require_relative "../../lib/ores_app/controller_runtime"
require_relative "../../lib/ores_app/handlers"
require_relative "../../lib/ores_app/middleware"
require_relative "../../lib/ores_app/routes"

class OresEndpointController < ApplicationController
  skip_forgery_protection
  around_action :run_ores_route_middleware

  class << self
    def call_ores_action(action, request)
      OresApp::ControllerRuntime.call(self, action, request)
    end
  end

  private

  # Compatibility helper for simple endpoints. Custom actions may ignore this
  # entirely; Graal/Lambda invoke the action itself.
  def dispatch_ores_endpoint
    result = OresApp::Handlers.call(self.class.controller_path, action_name, ores_request_envelope)

    result.fetch(:headers, {}).each do |name, value|
      next if %w[content-length content-type].include?(name.to_s.downcase)
      response.set_header(name, value)
    end

    payload = result.fetch(:body)
    payload = JSON.parse(payload) if payload.is_a?(String)
    model = endpoint_model_class.new(payload)

    format = request.headers["Accept"].to_s.downcase.include?("text/html") ? :html : :json
    render(
      template: "#{self.class.controller_path}/#{action_name}",
      formats: [format],
      locals: { model: model },
      status: result.fetch(:status)
    )
  end

  def run_ores_route_middleware
    middleware_request = ores_request_envelope
    result = OresApp::Middleware.call(route_middleware, middleware_request) do
      request.set_header("action_dispatch.request_id", middleware_request["request_id"].to_s)
      yield
      {
        status: response.status,
        headers: response.headers.to_h,
        body: response.body.to_s
      }
    end

    self.status = result.fetch(:status)
    result.fetch(:headers, {}).each { |name, value| response.set_header(name, value) }
    self.response_body = result[:body] if result.key?(:body) && result[:body].to_s != response.body.to_s
  end

  def route_middleware
    request.path_parameters[:ores_middleware] ||
      request.path_parameters["ores_middleware"] ||
      OresApp::Routes::DEFAULT_MIDDLEWARE
  end

  def ores_request_envelope
    path_params = request.path_parameters.to_h.reject do |key, _|
      %w[controller action ores_middleware].include?(key.to_s)
    end

    {
      "request_id" => request.request_id,
      "method" => request.request_method,
      "path" => request.path,
      "query" => request.query_parameters,
      "headers" => request.headers.to_h.select { |name, _| %w[accept content-type x-request-id].include?(name.to_s.downcase) },
      "content_type" => request.content_type,
      "body" => parsed_body,
      "path_params" => path_params
    }
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
