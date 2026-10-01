require "rack/mock"

module OresRuntime
  module RackDispatch
    TEXTUAL_MEDIA_TYPES = [
      "application/json",
      "application/problem+json",
      "application/javascript",
      "application/xml",
      "application/x-www-form-urlencoded",
      "text/"
    ].freeze

    module_function

    def call(app, request)
      method = request.fetch("method").to_s.upcase
      path = request.fetch("path").to_s
      raise ArgumentError, "path must begin with /" unless path.start_with?("/")

      query = request.fetch("query_string", "").to_s
      target = query.empty? ? path : "#{path}?#{query}"
      body_string = request.fetch("body", "").to_s
      headers = normalize_headers(request.fetch("headers", {}))
      request_id = request.fetch("request_id").to_s

      env = Rack::MockRequest.env_for(target, method: method, input: body_string)
      headers.each do |name, value|
        rack_name = rack_header_name(name)
        next if rack_name.nil?
        env[rack_name] = value
      end
      env["CONTENT_LENGTH"] = body_string.bytesize.to_s unless body_string.empty?
      env["HTTP_X_REQUEST_ID"] = request_id unless request_id.empty?

      status, response_headers, response_body = app.call(env)
      chunks = []
      begin
        response_body.each { |chunk| chunks << chunk.to_s }
      ensure
        response_body.close if response_body.respond_to?(:close)
      end

      {
        "status" => Integer(status),
        "headers" => normalize_response_headers(response_headers),
        "body" => chunks.join
      }
    end

    def textual_media_type?(content_type)
      media_type = content_type.to_s.split(";", 2).first.to_s.downcase
      TEXTUAL_MEDIA_TYPES.any? { |prefix| media_type == prefix || media_type.start_with?(prefix) }
    end

    def normalize_headers(headers)
      headers.each_with_object({}) do |(name, value), result|
        next if name.nil? || value.nil?
        normalized_name = name.to_s.downcase
        next unless normalized_name.match?(/\A[a-z0-9!#$%&'*+.^_`|~-]+(?:-[a-z0-9!#$%&'*+.^_`|~-]+)*\z/)
        result[normalized_name] = Array(value).join(",")
      end
    end

    def normalize_response_headers(headers)
      headers.each_with_object({}) do |(name, value), result|
        next if name.nil? || value.nil?
        result[name.to_s.downcase] = Array(value).join(",")
      end
    end

    def rack_header_name(name)
      canonical = name.to_s.downcase
      return "CONTENT_TYPE" if canonical == "content-type"
      return "CONTENT_LENGTH" if canonical == "content-length"
      return nil if canonical == "connection"
      "HTTP_#{canonical.upcase.tr('-', '_')}"
    end
  end
end
