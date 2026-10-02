require_relative "boot"

require "rails"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module OresRor
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = false
    config.autoload_lib(ignore: %w[assets tasks])
  end
end
