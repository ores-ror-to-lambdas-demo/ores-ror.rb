# frozen_string_literal: true

module OresApp
  module Middleware
    KNOWN = %w[
      request_id
      users_show_header
      order_cancel_header
      search_header
    ].freeze

    module_function

    def call(names, request)
      normalized = normalize_names(names)
      chain = normalized.reverse.inject(-> { yield }) do |next_step, name|
        -> { invoke(name, request, next_step) }
      end

      response = chain.call
      response[:headers] ||= {}
      response[:headers]["x-ores-middleware-chain"] = normalized.join(",")
      response
    end

    def normalize_names(value)
      names =
        case value
        when nil
          []
        when String
          value.split(",")
        else
          Array(value)
        end

      names = names.map { |name| name.to_s.strip }.reject(&:empty?)
      raise ArgumentError, "middleware chain must not be empty" if names.empty?

      unknown = names - KNOWN
      raise ArgumentError, "unknown middleware: #{unknown.join(", ")}" unless unknown.empty?
      names
    end

    def invoke(name, request, next_step)
      case name.to_s
      when "request_id"
        request["request_id"] = normalized_request_id(request["request_id"])
        response = next_step.call
        response[:headers] ||= {}
        response[:headers]["x-request-id"] = request["request_id"]
        response
      when "users_show_header"
        with_route_policy_header(next_step, "users-show")
      when "order_cancel_header"
        with_route_policy_header(next_step, "order-cancel")
      when "search_header"
        with_route_policy_header(next_step, "search")
      else
        raise ArgumentError, "unknown middleware: #{name}"
      end
    end

    def with_route_policy_header(next_step, value)
      response = next_step.call
      response[:headers] ||= {}
      response[:headers]["x-ores-route-policy"] = value
      response
    end

    def normalized_request_id(value)
      candidate = value.to_s
      return candidate if candidate.match?(/\A[A-Za-z0-9._:-]{1,128}\z/)

      raise ArgumentError, "valid request_id is required at the ingress boundary"
    end
    private_class_method :invoke, :with_route_policy_header, :normalized_request_id
  end
end
