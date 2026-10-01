# frozen_string_literal: true

ORES_GRAAL_RUNTIME = true unless defined?(ORES_GRAAL_RUNTIME)
ORES_GS_HTTP = method(:gs_http) unless defined?(ORES_GS_HTTP)

app_root = gs_app_root.to_s
entrypoint = File.join(app_root, "generated", "lambda", "entrypoint.rb")
raise "lambda runtime not generated; run ORES_BUILD_TARGET=lambda ruby bin/build-runtime" unless File.file?(entrypoint)

require "json"
require entrypoint

def ores_lambda_invoke(request_json)
  request = JSON.parse(request_json)
  JSON.generate(OresGenerated::LambdaEntrypoint.call(request))
end

method(:ores_lambda_invoke)
