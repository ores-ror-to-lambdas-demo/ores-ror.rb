# This file is appended to the generated single-source Graal bundle.
# It must not require Rails, Bundler, application files, or guest filesystem access.

def ores_faas_invoke(request_json)
  request = JSON.parse(request_json.to_s)
  JSON.generate(OresRuntime::CoreDispatch.call(request))
end

method(:ores_faas_invoke)
