require "securerandom"

module OresApp
  module Middleware
    class RequestId
      def self.call(request)
        copy = request.dup
        request_id = copy["request_id"].to_s
        copy["request_id"] = request_id.empty? ? "ores-req-#{SecureRandom.hex(8)}" : request_id
        yield copy
      end
    end

    STACK = [RequestId].freeze

    module_function

    def call(request, &terminal)
      chain = STACK.reverse.inject(terminal) do |next_step, middleware|
        ->(current) { middleware.call(current, &next_step) }
      end
      chain.call(request)
    end
  end
end
