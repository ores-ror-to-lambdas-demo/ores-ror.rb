# frozen_string_literal: true

require "securerandom"

module OresApp
  module Middleware
    module_function

    def call(names, request)
      chain = Array(names).reverse.inject(-> { yield }) do |next_step, name|
        -> { invoke(name, request, next_step) }
      end
      chain.call
    end

    def invoke(name, request, next_step)
      case name.to_s
      when "request_id"
        request["request_id"] = normalized_request_id(request["request_id"])
        response = next_step.call
        response[:headers] ||= {}
        response[:headers]["x-request-id"] = request["request_id"]
        response
      else
        raise ArgumentError, "unknown middleware: #{name}"
      end
    end

    def normalized_request_id(value)
      candidate = value.to_s
      return candidate if candidate.match?(/\A[A-Za-z0-9._:-]{1,128}\z/)

      "ores-req-#{SecureRandom.hex(12)}"
    end
    private_class_method :invoke, :normalized_request_id
  end
end
