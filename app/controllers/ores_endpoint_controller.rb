# frozen_string_literal: true

require "json"
require_relative "application_controller"
require_relative "../../lib/ores_app/controller_runtime"
require_relative "../../lib/ores_app/handlers"
require_relative "../../lib/ores_app/middleware"
require_relative "../../lib/ores_app/routes"
require_relative "../../lib/ores_app/view_runtime"

module OresEndpointBehavior
  module ClassMethods
    def call_ores_action(action, request)
      OresApp::ControllerRuntime.call(self, action, request)
    end

    def controller_path
      return super if defined?(Rails)

      name
        .sub(/::EndpointController\z/, "/endpoint")
        .gsub("::", "/")
        .gsub(/([a-z0-9])([A-Z])/, "\\1_\\2")
        .downcase
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  private

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

  def route_middleware
    request.path_parameters[:ores_middleware] ||
      request.path_parameters["ores_middleware"] ||
      OresApp::Routes::DEFAULT_MIDDLEWARE
  end

  def ores_request_envelope
    path_params = request.path_parameters.to_h.each_with_object({}) do |(key, value), out|
      next if %w[controller action ores_middleware].include?(key.to_s)
      out[key.to_s] = value
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
    singular = resource.end_with?("ies") ? resource.sub(/ies\z/, "y") : resource.sub(/s\z/, "")
    token = singular == resource ? "#{resource}_record" : singular
    Object.const_get(token.split("_").map(&:capitalize).join)
  end

  def parsed_body
    raw = request.raw_post.to_s
    return nil if raw.empty?
    return JSON.parse(raw) if request.content_type.to_s.include?("json")

    raw
  rescue JSON::ParserError => error
    raise OresApp::BadRequest, "invalid JSON body: #{error.message}"
  end
end

if defined?(Rails)
  class OresEndpointController < ApplicationController
    include OresEndpointBehavior

    skip_forgery_protection
    around_action :run_ores_route_middleware

    private

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
  end
else
  class OresEndpointController
    include OresEndpointBehavior

    attr_reader :request, :response, :params, :action_name

    def __ores_invoke(action, request_hash)
      @action_name = action.to_s
      @request = OresApp::PlainRequest.new(request_hash, action: @action_name, controller: self.class.controller_path)
      @response = OresApp::PlainResponse.new
      @params = request.path_parameters

      result = OresApp::Middleware.call(route_middleware, ores_request_envelope) do
        public_send(@action_name)
        {
          status: response.status,
          headers: response.headers.to_h,
          body: response.body.to_s
        }
      end

      result.fetch(:headers, {}).each { |name, value| response.set_header(name, value) }
      response.status = result.fetch(:status)
      response.body = result.fetch(:body).to_s
      { status: response.status, headers: response.headers.to_h, body: response.body }
    rescue OresApp::BadRequest => error
      render_error(400, error.message)
    rescue OresApp::HttpDatabase::Error => error
      render_error(502, error.message)
    end

    def render(template:, formats:, locals:, status:)
      format = Array(formats).first.to_sym
      response.status = Integer(status)
      response.set_header("content-type", format == :html ? "text/html; charset=utf-8" : "application/json; charset=utf-8")
      response.body = OresApp::ViewRuntime.render(template, format, locals)
    end

    private

    def render_error(status, message)
      body = JSON.generate(ok: false, error: message)
      {
        status: status,
        headers: { "content-type" => "application/json; charset=utf-8" },
        body: body
      }
    end
  end
end
