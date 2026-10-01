# frozen_string_literal: true
# Appended to generated/graal/handler.rb by bin/build-runtime.
# The generated bundle is evaluated exactly once per long-lived Graal Context.

module OresGenerated
  module GraalEntrypoint
    module_function

    def call(request)
      previous = Thread.current[:ores_invocation_context]
      raise "invocation context leaked across worker reuse" if previous

      Thread.current[:ores_invocation_context] = request
      begin
        OresApp::Dispatcher.call(request, invoker: method(:invoke))
      ensure
        Thread.current[:ores_invocation_context] = nil
      end
    end
  end
end

def ores_graal_invoke(request_json)
  request = JSON.parse(request_json.to_s)
  JSON.generate(OresGenerated::GraalEntrypoint.call(request))
end

# Return a factory instead of trying method(:gs_http). The host passes its
# capability explicitly once, during Context initialization, then keeps the
# returned invoker warm for the lifetime of the isolate.
->(http_capability, context_id = nil) do
  Object.const_set(:ORES_GS_HTTP, http_capability) unless defined?(ORES_GS_HTTP)
  Object.const_set(:ORES_GRAAL_CONTEXT_ID, context_id.to_s.freeze) unless defined?(ORES_GRAAL_CONTEXT_ID)
  method(:ores_graal_invoke)
end
