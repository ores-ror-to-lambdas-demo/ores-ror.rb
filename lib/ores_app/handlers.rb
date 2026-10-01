# frozen_string_literal: true

require_relative "http_database"

module OresApp
  module Handlers
    module_function

    def call(controller_path, action, request)
      key = "#{controller_path}##{action}"

      case key
      when "users/show/endpoint#show"                then proxy(:get,  "/users/#{safe_id(request)}")
      when "carts/show/endpoint#show"                then proxy(:get,  "/carts/#{safe_id(request)}")
      when "checkout_sessions/create/endpoint#create" then proxy(:post, "/checkout-sessions/#{safe_id(request)}", body: request["body"])
      when "products/show/endpoint#show"             then proxy(:get,  "/products/#{safe_id(request)}")
      when "orders/show/endpoint#show"               then proxy(:get,  "/orders/#{safe_id(request)}")
      when "orders/cancel/endpoint#cancel"           then proxy(:post, "/orders/#{safe_id(request)}/cancel", body: request["body"])
      when "accounts/show/endpoint#show"             then proxy(:get,  "/accounts/#{safe_id(request)}")
      when "inventory/show/endpoint#show"            then proxy(:get,  "/inventory/#{safe_id(request)}")
      when "recommendations/show/endpoint#show"      then proxy(:get,  "/recommendations/#{safe_id(request)}", query: request["query"])
      when "search/index/endpoint#index"             then proxy(:get,  "/search", query: request["query"])
      when "sessions/create/endpoint#create"         then proxy(:post, "/sessions", body: request["body"])
      when "profiles/preferences/show/endpoint#show" then proxy(:get,  "/profiles/#{safe_id(request)}/preferences")
      when "healthz/show/endpoint#show"              then health(request)
      else
        response(500, { error: "unknown Rails endpoint", controller: controller_path.to_s, action: action.to_s })
      end
    end

    def health(request)
      response(200, {
        ok: true,
        service: "ores-ror.rb",
        runtime: HttpDatabase.runtime_name,
        execution_mode: execution_mode,
        request_id: request["request_id"]
      })
    end

    def execution_mode
      return "lambda" if defined?(ORES_GRAAL_RUNTIME) && ORES_GRAAL_RUNTIME

      ENV.fetch("ORES_BUILD_TARGET", "rails")
    end

    def proxy(method, path, body: nil, query: nil)
      result = HttpDatabase.request(method, path, body: body, query: query || {})
      response(result.fetch(:status), result.fetch(:body))
    end

    def safe_id(request)
      value = request.fetch("path_params", {}).fetch("id", "").to_s
      raise ArgumentError, "invalid id" unless value.match?(/\A[A-Za-z0-9_-]{1,128}\z/)
      value
    end

    def response(status, body)
      {
        status: Integer(status),
        headers: { "content-type" => "application/json; charset=utf-8" },
        body: body
      }
    end
    private_class_method :health, :execution_mode, :proxy, :safe_id, :response
  end
end
