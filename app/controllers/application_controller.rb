# frozen_string_literal: true

require "action_controller"
require "action_view"
require_relative "../../lib/ores_app/http_database"

class ApplicationController < ActionController::Base
  if defined?(ORES_EMBEDDED_ACTION_VIEW) && ORES_EMBEDDED_ACTION_VIEW
    prepend_view_path OresApp::EmbeddedViews.resolver
  else
    prepend_view_path File.expand_path("../views", __dir__)
  end

  rescue_from OresApp::HttpDatabase::Error do |error|
    render json: { ok: false, error: error.message }, status: :bad_gateway
  end

  rescue_from ActionController::BadRequest do |error|
    render json: { ok: false, error: error.message }, status: :bad_request
  end
end
