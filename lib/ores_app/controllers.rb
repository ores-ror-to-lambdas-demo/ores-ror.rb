# frozen_string_literal: true

require_relative "handlers"
require_relative "routes"

module OresApp
  module Controllers
    class Base
      class << self
        attr_reader :controller_path

        def handles(value)
          @controller_path = value.to_s.freeze
        end

        def call(action, request)
          route = Routes.for_controller_action(controller_path, action)
          raise KeyError, "unknown controller action #{controller_path}##{action}" unless route

          Handlers.call(route.handler, request)
        end
      end
    end

    class Users < Base; handles "users"; end
    class Carts < Base; handles "carts"; end
    class CheckoutSessions < Base; handles "checkout_sessions"; end
    class Products < Base; handles "products"; end
    class Orders < Base; handles "orders"; end
    class Accounts < Base; handles "accounts"; end
    class Inventory < Base; handles "inventory"; end
    class Recommendations < Base; handles "recommendations"; end
    class Search < Base; handles "search"; end
    class Sessions < Base; handles "sessions"; end
    class Profiles < Base; handles "profiles"; end
    class Health < Base; handles "health"; end

    module_function

    def fetch(controller_path)
      name = controller_path.to_s.split("/").map { |part| part.split("_").map(&:capitalize).join }.join("::")
      const_get(name, false)
    end
  end
end
