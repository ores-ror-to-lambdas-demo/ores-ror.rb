# frozen_string_literal: true
# This source is appended to generated/graal/handler.rb by bin/build-runtime.
# It deliberately has no filesystem, Bundler, or Rails dependency.

def ores_graal_invoke(request_json)
  request = JSON.parse(request_json.to_s)
  JSON.generate(OresApp::Dispatcher.call(request))
end

method(:ores_graal_invoke)
