# frozen_string_literal: true

require "json"
require "rack/mock"
require "uri"

module OresApp
  module ControllerRuntime
    module_function

    def call(controller_class, action, request)
      status, headers, body = controller_class.action(action.to_s).call(rack_env(request, action))
      chunks = []
      body.each { |chunk| chunks << chunk.to_s }
      body.close if body.respond_to?(:close)

      {
        status: Integer(status),
        headers: headers.to_h,
        body: chunks.join
      }
    end

    def rack_env(request, action)
      query_string = encode_query(request.fetch("query", {}))
      path = request.fetch("path", "/").to_s
      path = "#{path}?#{query_string}" unless query_string.empty?
      raw_body = encode_body(request["body"])
      headers = request.fetch("headers", {})
      content_type = request["content_type"].to_s
      content_type = headers["content-type"].to_s if content_type.empty?
      content_type = "application/json" if content_type.empty? && !raw_body.empty?

      options = { method: request.fetch("method", "GET").to_s.upcase, input: raw_body }
      options["CONTENT_TYPE"] = content_type unless content_type.empty?
      headers.each do |name, value|
        key = rack_header_name(name)
        next if key == "CONTENT_TYPE"
        options[key] = value.to_s
      end

      env = Rack::MockRequest.env_for(path, options)
      env["action_dispatch.request_id"] = request["request_id"].to_s
      env["action_dispatch.request.path_parameters"] = path_parameters(request, action)
      env
    end

    def path_parameters(request, action)
      params = request.fetch("path_params", {}).each_with_object({}) do |(key, value), out|
        out[key.to_s] = value
      end
      params["controller"] = request["controller"].to_s
      params["action"] = action.to_s
      middleware = request["middleware"]
      params["ores_middleware"] = Array(middleware).join(",") if middleware
      params
    end

    def encode_body(body)
      return "" if body.nil?
      return body if body.is_a?(String)
      JSON.generate(body)
    end

    def encode_query(query)
      pairs = query.flat_map do |key, value|
        Array(value).map { |entry| [key.to_s, entry.to_s] }
      end
      URI.encode_www_form(pairs)
    end

    def rack_header_name(name)
      token = name.to_s.upcase.tr("-", "_")
      return token if %w[CONTENT_TYPE CONTENT_LENGTH].include?(token)
      "HTTP_#{token}"
    end
    private_class_method :rack_env, :path_parameters, :encode_body, :encode_query, :rack_header_name
  end
end
