# frozen_string_literal: true
# Appended to generated/graal/handler.rb by bin/build-runtime.
# The generated bundle is evaluated exactly once per long-lived Graal Context.

raise "Graal host did not bind ores_gs_http" unless defined?(ores_gs_http)
ORES_GS_HTTP = ores_gs_http unless defined?(ORES_GS_HTTP)

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

method(:ores_graal_invoke)
