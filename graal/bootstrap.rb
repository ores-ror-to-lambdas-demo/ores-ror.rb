# frozen_string_literal: true
# Appended to generated/graal/handler.rb at build time. No Rails or filesystem load.

def ores_graal_invoke(request_json)
  OresApp::ThreadStateBoundary.call do
    request = JSON.parse(request_json.to_s)
    JSON.generate(OresApp::Dispatcher.call(request))
  end
end

method(:ores_graal_invoke)
