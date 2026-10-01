# frozen_string_literal: true

ORES_GRAAL_RUNTIME = true unless defined?(ORES_GRAAL_RUNTIME)

runtime_binding = binding
fetch_host_binding = lambda do |name|
  unless runtime_binding.local_variable_defined?(name)
    raise "missing Graal host binding: #{name}"
  end
  runtime_binding.local_variable_get(name)
end

ORES_GS_HTTP = fetch_host_binding.call(:gs_http) unless defined?(ORES_GS_HTTP)

app_root = fetch_host_binding.call(:gs_app_root).to_s
entrypoint = File.join(app_root, "generated", "lambda", "entrypoint.rb")
raise "lambda runtime not generated; run ORES_BUILD_TARGET=lambda ruby bin/build-runtime" unless File.file?(entrypoint)

require "json"
require File.join(app_root, "lib", "ores_app", "thread_state_boundary")
require entrypoint

def ores_lambda_invoke(request_json)
  OresApp::ThreadStateBoundary.call do
    request = JSON.parse(request_json)
    JSON.generate(OresGenerated::LambdaEntrypoint.call(request))
  end
end

method(:ores_lambda_invoke)
