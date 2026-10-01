# frozen_string_literal: true

require "uri"

module OresApp
  module Routes
    Route = Struct.new(
      :verb, :path, :handler, :name, :middleware, :group, :pool,
      :endpoint, :controller, :action,
      keyword_init: true
    )

    DEFAULT_MIDDLEWARE = %w[request_id].freeze

    TABLE = [
      Route.new(verb: "GET",  path: "/users/:id",                handler: "user",             name: "user",             middleware: DEFAULT_MIDDLEWARE, group: "users",           pool: "users",           endpoint: "users/show",                controller: "users/show/users",                         action: "show"),
      Route.new(verb: "GET",  path: "/carts/:id",                handler: "cart",             name: "cart",             middleware: DEFAULT_MIDDLEWARE, group: "carts",           pool: "carts",           endpoint: "carts/show",                controller: "carts/show/carts",                         action: "show"),
      Route.new(verb: "POST", path: "/checkout-sessions/:id",    handler: "checkout_session", name: "checkout_session", middleware: DEFAULT_MIDDLEWARE, group: "checkout",        pool: "checkout",        endpoint: "checkout_sessions/create", controller: "checkout_sessions/create/checkout_sessions", action: "create"),
      Route.new(verb: "GET",  path: "/products/:id",             handler: "product",          name: "product",          middleware: DEFAULT_MIDDLEWARE, group: "products",        pool: "products",        endpoint: "products/show",             controller: "products/show/products",                    action: "show"),
      Route.new(verb: "GET",  path: "/orders/:id",               handler: "order",            name: "order",            middleware: DEFAULT_MIDDLEWARE, group: "orders",          pool: "orders",          endpoint: "orders/show",               controller: "orders/show/orders",                        action: "show"),
      Route.new(verb: "POST", path: "/orders/:id/cancel",        handler: "cancel_order",     name: "cancel_order",     middleware: DEFAULT_MIDDLEWARE, group: "orders",          pool: "orders",          endpoint: "orders/cancel",             controller: "orders/cancel/orders",                      action: "cancel"),
      Route.new(verb: "GET",  path: "/accounts/:id",             handler: "account",          name: "account",          middleware: DEFAULT_MIDDLEWARE, group: "accounts",        pool: "accounts",        endpoint: "accounts/show",             controller: "accounts/show/accounts",                    action: "show"),
      Route.new(verb: "GET",  path: "/inventory/:id",            handler: "inventory",        name: "inventory",        middleware: DEFAULT_MIDDLEWARE, group: "inventory",       pool: "inventory",       endpoint: "inventory/show",            controller: "inventory/show/inventory",                  action: "show"),
      Route.new(verb: "GET",  path: "/recommendations/:id",      handler: "recommendations",  name: "recommendations",  middleware: DEFAULT_MIDDLEWARE, group: "recommendations", pool: "recommendations", endpoint: "recommendations/show",      controller: "recommendations/show/recommendations",      action: "show"),
      Route.new(verb: "GET",  path: "/search",                   handler: "search",           name: "search",           middleware: DEFAULT_MIDDLEWARE, group: "search",          pool: "search",          endpoint: "search/index",              controller: "search/index/search",                       action: "index"),
      Route.new(verb: "POST", path: "/sessions",                 handler: "create_session",   name: "sessions",         middleware: DEFAULT_MIDDLEWARE, group: "sessions",        pool: "sessions",        endpoint: "sessions/create",           controller: "sessions/create/sessions",                  action: "create"),
      Route.new(verb: "GET",  path: "/profiles/:id/preferences", handler: "preferences",      name: "preferences",      middleware: DEFAULT_MIDDLEWARE, group: "profiles",        pool: "profiles",        endpoint: "profiles/preferences",      controller: "profiles/preferences/profiles",             action: "preferences"),
      Route.new(verb: "GET",  path: "/healthz",                  handler: "health",           name: "health",           middleware: DEFAULT_MIDDLEWARE, group: "system",          pool: "system",          endpoint: "healthz/show",              controller: "healthz/show/healthz",                       action: "show")
    ].freeze

    module_function

    def install_rails(router)
      TABLE.each do |route|
        router.public_send(
          route.verb.downcase,
          route.path,
          to: "#{route.controller}##{route.action}",
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

    def endpoint_dir(route)
      File.join("app", "controllers", route.endpoint)
    end

    def controller_relative_path(route)
      File.join("app", "controllers", "#{route.controller}_controller.rb")
    end

    def controller_path(route)
      File.expand_path(File.join("../..", controller_relative_path(route)), __dir__)
    end

    def handler_relative_path(route)
      File.join(endpoint_dir(route), "handler.rb")
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
          controller: route.controller,
          action: route.action,
          source_controller: controller_relative_path(route),
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
