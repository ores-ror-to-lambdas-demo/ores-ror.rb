require_relative "boot"

require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require_relative "../lib/ores_rails/puma_io_bound"

Bundler.require(*Rails.groups)

module OresRor
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = false
    config.autoload_lib(ignore: %w[assets tasks])

    # Classify data-backed requests before controller execution so Puma can
    # preserve regular request capacity while those requests wait on HTTP I/O.
    config.middleware.insert_before 0, OresRails::PumaIoBound
  end
end
