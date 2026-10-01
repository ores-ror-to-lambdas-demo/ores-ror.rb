class ApplicationController < ActionController::API
  rescue_from HttpDatabase::Error do |error|
    render json: { ok: false, error: error.message }, status: :bad_gateway
  end
end
