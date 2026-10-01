# frozen_string_literal: true

require_relative "http_database"

module OresApp
  module RouteHandler
    module_function

    def proxy(method, path, body: nil, query: nil)
      result = HttpDatabase.request(method, path, body: body, query: query || {})
      response(result.fetch(:status), result.fetch(:body))
    end

    def safe_id(request)
      value = request.fetch("path_params", {}).fetch("id", "").to_s
      raise ArgumentError, "invalid id" unless value.match?(/\A[A-Za-z0-9_-]{1,128}\z/)
      value
    end

    def health(request)
      execution_mode = if defined?(ORES_EXECUTION_MODE)
        ORES_EXECUTION_MODE
      else
        ENV.fetch("ORES_BUILD_TARGET", "rails")
      end

      response(200, {
        ok: true,
        service: "ores-ror.rb",
        runtime: HttpDatabase.runtime_name,
        execution_mode: execution_mode,
        request_id: request["request_id"]
      })
    end

    def response(status, body)
      {
        status: Integer(status),
        headers: { "content-type" => "application/json; charset=utf-8" },
        body: body
      }
    end
  end
end
