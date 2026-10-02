# frozen_string_literal: true

require_relative "../../lib/ores_app/http_database"
require_relative "../../lib/ores_app/controller_runtime"

class ApplicationController < ActionController::Base
  rescue_from OresApp::HttpDatabase::Error do |error|
    render json: { ok: false, error: error.message }, status: :bad_gateway
  end

  rescue_from OresApp::BadRequest do |error|
    render json: { ok: false, error: error.message }, status: :bad_request
  end
end
