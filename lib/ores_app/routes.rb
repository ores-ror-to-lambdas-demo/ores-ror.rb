# frozen_string_literal: true

require "uri"

module OresApp
  module Routes
    Route = Struct.new(
      :verb, :path, :handler, :name, :middleware, :group, :pool,
      :controller, :action, :endpoint_dir,
      keyword_init: true
    )

    DEFAULT_MIDDLEWARE = %w[request_id].freeze

    TABLE = [
      Route.new(verb: "GET", path: "/users/:id", handler: "user", name: "user", middleware: DEFAULT_MIDDLEWARE, group: "users", pool: "users", controller: "users/show/endpoint", action: "call", endpoint_dir: "app/controllers/users/show"),
      Route.new(verb: "GET", path: "/carts/:id", handler: "cart", name: "cart", middleware: DEFAULT_MIDDLEWARE, group: "carts", pool: "carts", controller: "carts/show/endpoint", action: "call", endpoint_dir: "app/controllers/carts/show"),
      Route.new(verb: "POST", path: "/checkout-sessions/:id", handler: "checkout_session", name: "checkout_session", middleware: DEFAULT_MIDDLEWARE, group: "checkout", pool: "checkout", controller: "checkout_sessions/create/endpoint", action: "call", endpoint_dir: "app/controllers/checkout_sessions/create"),
      Route.new(verb: "GET", path: "/products/:id", handler: "product", name: "product", middleware: DEFAULT_MIDDLEWARE, group: "products", pool: "products", controller: "products/show/endpoint", action: "call", endpoint_dir: "app/controllers/products/show"),
      Route.new(verb: "GET", path: "/orders/:id", handler: "order", name: "order", middleware: DEFAULT_MIDDLEWARE, group: "orders", pool: "orders", controller: "orders/show/endpoint", action: "call", endpoint_dir: "app/controllers/orders/show"),
      Route.new(verb: "POST", path: "/orders/:id/cancel", handler: "cancel_order", name: "cancel_order", middleware: DEFAULT_MIDDLEWARE, group: "orders", pool: "orders", controller: "orders/cancel/endpoint", action: "call", endpoint_dir: "app/controllers/orders/cancel"),
      Route.new(verb: "GET", path: "/accounts/:id", handler: "account", name: "account", middleware: DEFAULT_MIDDLEWARE, group: "accounts", pool: "accounts", controller: "accounts/show/endpoint", action: "call", endpoint_dir: "app/controllers/accounts/show"),
      Route.new(verb: "GET", path: "/inventory/:id", handler: "inventory", name: "inventory", middleware: DEFAULT_MIDDLEWARE, group: "inventory", pool: "inventory", controller: "inventory/show/endpoint", action: "call", endpoint_dir: "app/controllers/inventory/show"),
      Route.new(verb: "GET", path: "/recommendations/:id", handler: "recommendations", name: "recommendations", middleware: DEFAULT_MIDDLEWARE, group: "recommendations", pool: "recommendations", controller: "recommendations/show/endpoint", action: "call", endpoint_dir: "app/controllers/recommendations/show"),
      Route.new(verb: "GET", path: "/search", handler: "search", name: "search", middleware: DEFAULT_MIDDLEWARE, group: "search", pool: "search", controller: "search/index/endpoint", action: "call", endpoint_dir: "app/controllers/search/index"),
      Route.new(verb: "POST", path: "/sessions", handler: "create_session", name: "sessions", middleware: DEFAULT_MIDDLEWARE, group: "sessions", pool: "sessions", controller: "sessions/create/endpoint", action: "call", endpoint_dir: "app/controllers/sessions/create"),
      Route.new(verb: "GET", path: "/profiles/:id/preferences", handler: "preferences", name: "preferences", middleware: DEFAULT_MIDDLEWARE, group: "profiles", pool: "profiles", controller: "profiles/preferences/show/endpoint", action: "call", endpoint_dir: "app/controllers/profiles/preferences/show"),
      Route.new(verb: "GET", path: "/healthz", handler: "health", name: "health", middleware: DEFAULT_MIDDLEWARE, group: "system", pool: "system", controller: "healthz/show/endpoint", action: "call", endpoint_dir: "app/controllers/healthz/show"),
    ].freeze

    module_function

    def install_rails(router)
      TABLE.each do |route|
        router.public_send(
          route.verb.downcase,
          route.path,
          to: "#{route.controller}##{route.action}",
          defaults: { ores_handler: route.handler, ores_route_name: route.name },
          as: route.name.to_sym
        )
      end
    end

    def match(method, path)
      verb = method.to_s.upcase
      TABLE.each do |route|
        next unless route.verb == verb

        match = route_pattern(route.path).match(path.to_s)
        next unless match

        params = match.named_captures.transform_values { |value| URI.decode_www_form_component(value) }
        return [route, params]
      end
      nil
    end

    def controller_relative_path(route)
      File.join(route.endpoint_dir, "endpoint_controller.rb")
    end

    def controller_path(route)
      File.expand_path(File.join("../..", controller_relative_path(route)), __dir__)
    end

    def handler_relative_path(route)
      File.join(route.endpoint_dir, "handler.rb")
    end

    def handler_path(route)
      File.expand_path(File.join("../..", handler_relative_path(route)), __dir__)
    end

    def manifest
      TABLE.map do |route|
        {
          method: route.verb,
          path: route.path,
          handler: route.handler,
          name: route.name,
          middleware: route.middleware,
          group: route.group,
          pool: route.pool,
          rails_controller: route.controller,
          rails_action: route.action,
          endpoint_dir: route.endpoint_dir,
          generated_handler: handler_relative_path(route)
        }
      end
    end

    def route_pattern(path)
      pieces = path.split("/", -1).map do |piece|
        if piece.start_with?(":")
          "(?<#{piece.delete_prefix(":")}>[^/]+)"
        else
          Regexp.escape(piece)
        end
      end
      Regexp.new("\\A#{pieces.join("/")}\\z")
    end
    private_class_method :route_pattern
  end
end
