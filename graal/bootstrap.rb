# frozen_string_literal: true
# Appended to generated/graal/handler.rb by bin/build-runtime.
# The generated source is evaluated exactly once per long-lived Graal Context.

if defined?(ores_gs_http) && !defined?(ORES_GS_HTTP)
  ORES_GS_HTTP = ores_gs_http
end

module OresGenerated
  module GraalEntrypoint
    module_function

    def call(request)
      OresApp::ThreadStateBoundary.call do
        OresApp::Dispatcher.call(request, invoker: method(:invoke))
      end
    end
  end
end

def ores_graal_invoke(request_json)
  raise "Graal host HTTP capability is unavailable" unless defined?(ORES_GS_HTTP)

  request = JSON.parse(request_json.to_s)
  JSON.generate(OresGenerated::GraalEntrypoint.call(request))
end

request_invoker = method(:ores_graal_invoke)

# Embedded Java places `ores_gs_http` in TruffleRuby's interactive top-level
# language binding before evaluating this source. The alternate branch keeps
# standalone smoke tests and other hosts able to install the capability once.
->(*args) do
  if args.length == 1 && args.first.is_a?(String)
    request_invoker.call(args.first)
  else
    http_capability = args.fetch(0)
    Object.const_set(:ORES_GS_HTTP, http_capability) unless defined?(ORES_GS_HTTP)
    request_invoker
  end
end
