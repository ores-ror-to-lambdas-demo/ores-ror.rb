ORES_GRAAL_RUNTIME = true unless defined?(ORES_GRAAL_RUNTIME)
ORES_GS_HTTP = method(:gs_http) unless defined?(ORES_GS_HTTP)

app_root = gs_app_root.to_s
rails_env = gs_rails_env.to_s
bundle_path = File.join(app_root, "vendor", "bundle-truffleruby")
ENV["BUNDLE_GEMFILE"] = File.join(app_root, "Gemfile")
ENV["BUNDLE_PATH"] = bundle_path
ENV["RAILS_ENV"] = rails_env
ENV["RACK_ENV"] = rails_env
ENV["RAILS_LOG_TO_STDOUT"] = "1"

require "json"
require File.join(app_root, "lib", "ores_runtime", "rack_dispatch")
require File.join(app_root, "config", "environment")

Rails.application.eager_load!
ORES_RAILS_APP = Rails.application unless defined?(ORES_RAILS_APP)

def ores_rack_invoke(request_json)
  request = JSON.parse(request_json)
  JSON.generate(OresRuntime::RackDispatch.call(ORES_RAILS_APP, request))
end

method(:ores_rack_invoke)
