# frozen_string_literal: true

class ApplicationController < ActionController::Base
  require_relative "../../lib/ores_app/dispatcher"

  skip_forgery_protection

  private

  def dispatch_ores
    result = OresApp::Dispatcher.call({
      "request_id" => request.request_id,
      "method" => request.request_method,
      "path" => request.path,
      "headers" => request.headers.env.select { |key, _| key.start_with?("HTTP_") }.transform_keys { |key| key.delete_prefix("HTTP_").downcase.tr("_", "-") },
      "query_string" => request.query_string,
      "content_type" => request.content_type,
      "body" => request.raw_post
    })

    response.headers.update(result.fetch("headers"))
    render body: result.fetch("body"), status: result.fetch("status")
  end
end
