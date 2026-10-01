# frozen_string_literal: true

require "json"
require_relative "../../lib/ores_app/controllers"
require_relative "../../lib/ores_app/middleware"

class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session

  rescue_from OresApp::HttpDatabase::Error do |error|
    render json: { ok: false, error: error.message }, status: :bad_gateway
  end

  private

  def run_ores_controller(controller_path, action)
    route = OresApp::Routes.for_controller_action(controller_path, action)
    raise KeyError, "unknown route #{controller_path}##{action}" unless route

    envelope = ores_request_envelope
    result = OresApp::Middleware.call(route.middleware, envelope) do
      OresApp::Controllers.fetch(controller_path).call(action, envelope)
    end

    result.fetch(:headers, {}).each { |name, value| response.set_header(name, value) }
    @payload = result.fetch(:body)
    render template: route.view, formats: [:json], status: result.fetch(:status), layout: false
  end

  def ores_request_envelope
    {
      "request_id" => request.request_id,
      "method" => request.request_method,
      "path" => request.path,
      "path_params" => request.path_parameters.transform_keys(&:to_s),
      "query" => request.query_parameters,
      "headers" => request.headers.to_h.select { |name, _| %w[content-type x-request-id].include?(name.to_s.downcase) },
      "content_type" => request.content_type,
      "body" => request.request_parameters.presence
    }
  end
end
