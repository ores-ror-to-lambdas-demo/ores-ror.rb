# frozen_string_literal: true

require_relative "json_codec"

module OresApp
  class BadRequest < StandardError; end

  class PlainHeaders
    def initialize(values = {})
      @values = {}
      values.each { |name, value| self[name] = value }
    end

    def [](name)
      @values[name.to_s.downcase]
    end

    def []=(name, value)
      @values[name.to_s.downcase] = value.to_s
    end

    def to_h
      @values.dup
    end
  end

  class PlainRequest
    attr_reader :request_method, :path, :query_parameters, :headers, :content_type, :path_parameters

    def initialize(request, action:, controller:)
      @request_id = request["request_id"].to_s
      @request_method = request.fetch("method", "GET").to_s.upcase
      @path = request.fetch("path", "/").to_s
      @query_parameters = request.fetch("query", {})
      @headers = PlainHeaders.new(request.fetch("headers", {}))
      @content_type = request["content_type"].to_s
      @content_type = @headers["content-type"].to_s if @content_type.empty?
      @raw_body = request["body"].is_a?(String) ? request["body"] : (request["body"].nil? ? "" : JsonCodec.generate(request["body"]))
      @path_parameters = request.fetch("path_params", {}).each_with_object({}) do |(key, value), out|
        out[key.to_s] = value
        out[key.to_sym] = value
      end
      @path_parameters["controller"] = controller
      @path_parameters[:controller] = controller
      @path_parameters["action"] = action.to_s
      @path_parameters[:action] = action.to_s
      if request["middleware"]
        middleware = Array(request["middleware"]).join(",")
        @path_parameters["ores_middleware"] = middleware
        @path_parameters[:ores_middleware] = middleware
      end
    end

    def request_id
      @request_id
    end

    def raw_post
      @raw_body
    end
  end

  class PlainResponse
    attr_accessor :status, :body
    attr_reader :headers

    def initialize
      @status = 200
      @headers = PlainHeaders.new
      @body = ""
    end

    def set_header(name, value)
      @headers[name] = value
    end
  end

  module ControllerRuntime
    module_function

    def call(controller_class, action, request)
      controller_class.new.__ores_invoke(action.to_s, request)
    end
  end
end
