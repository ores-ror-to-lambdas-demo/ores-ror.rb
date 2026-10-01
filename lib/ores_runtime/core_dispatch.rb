require "json"

module OresRuntime
  module CoreDispatch
    class BadRequest < StandardError; end

    module_function

    def call(raw_request)
      request = normalize_request(raw_request)

      OresApp::Middleware.call(request) do |current|
        matched = OresApp::Routes.match(current["method"], current["path"])
        return json_response(404, { error: "route not found", request_id: current["request_id"] }, current["request_id"]) unless matched

        route, path_params = matched
        dispatch(route, current.merge("path_params" => path_params))
      end
    rescue BadRequest, ArgumentError => error
      json_response(400, { error: error.message }, raw_request["request_id"].to_s)
    rescue HttpDatabase::Error => error
      json_response(502, { error: error.message }, raw_request["request_id"].to_s)
    end

    def dispatch(route, request)
      return health_response(request) if route.health

      path = OresApp::Routes.expand(route.backend_path, request.fetch("path_params"))
      body = route.forward_body ? parse_body(request["body"]) : nil
      query = route.forward_query ? parse_query(request["query_string"]) : {}

      result = HttpDatabase.request(route.method.downcase.to_sym, path, body: body, query: query)
      json_response(result.fetch(:status), result.fetch(:body), request["request_id"])
    end

    def health_response(request)
      json_response(200, {
        ok: true,
        service: "ores-ror.rb",
        runtime: HttpDatabase.runtime_name,
        request_id: request["request_id"],
        worker_thread_id_for_diagnostics_only: Thread.current.object_id
      }, request["request_id"])
    end

    def normalize_request(raw)
      request = {}
      raw.each { |key, value| request[key.to_s] = value }
      request["method"] = request.fetch("method", "GET").to_s.upcase
      request["path"] = request.fetch("path", "/").to_s
      request["query_string"] = request.fetch("query_string", "").to_s
      request["body"] = request.fetch("body", "").to_s
      request["headers"] = normalize_headers(request.fetch("headers", {}))
      raise BadRequest, "path must begin with /" unless request["path"].start_with?("/")
      request
    end

    def normalize_headers(headers)
      headers.each_with_object({}) do |(name, value), result|
        next if name.nil? || value.nil?
        result[name.to_s.downcase] = Array(value).join(",")
      end
    end

    def parse_query(query_string)
      return {} if query_string.to_s.empty?

      query_string.to_s.split("&").each_with_object({}) do |pair, result|
        key, value = pair.split("=", 2)
        result[decode_form_component(key)] = decode_form_component(value.to_s)
      end
    end

    def decode_form_component(value)
      text = value.to_s.tr("+", " ")
      raise BadRequest, "invalid percent encoding" if text.match?(/%(?![0-9A-Fa-f]{2})/)
      text.gsub(/%([0-9A-Fa-f]{2})/) { [Regexp.last_match(1).to_i(16)].pack("C") }.force_encoding(Encoding::UTF_8)
    end

    def parse_body(body)
      return {} if body.to_s.empty?
      JSON.parse(body.to_s)
    rescue JSON::ParserError => error
      raise BadRequest, "invalid JSON body: #{error.message}"
    end

    def json_response(status, payload, request_id)
      {
        "status" => Integer(status),
        "headers" => {
          "content-type" => "application/json; charset=utf-8",
          "x-request-id" => request_id.to_s
        },
        "body" => JSON.generate(payload)
      }
    end
  end
end
