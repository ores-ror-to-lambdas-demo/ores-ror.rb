# frozen_string_literal: true

require "uri"

module OresApp
  module Routes
    Route = Struct.new(:verb, :path, :handler, :name, :middleware, :pool, keyword_init: true)

    DEFAULT_MIDDLEWARE = %w[request_id].freeze

    TABLE = [
      Route.new(verb: "GET",  path: "/users/:id",                handler: "user",             name: "user",             middleware: DEFAULT_MIDDLEWARE, pool: "resources"),
      Route.new(verb: "GET",  path: "/carts/:id",                handler: "cart",             name: "cart",             middleware: DEFAULT_MIDDLEWARE, pool: "resources"),
      Route.new(verb: "POST", path: "/checkout-sessions/:id",    handler: "checkout_session", name: "checkout_session", middleware: DEFAULT_MIDDLEWARE, pool: "resources"),
      Route.new(verb: "GET",  path: "/products/:id",             handler: "product",          name: "product",          middleware: DEFAULT_MIDDLEWARE, pool: "resources"),
      Route.new(verb: "GET",  path: "/orders/:id",               handler: "order",            name: "order",            middleware: DEFAULT_MIDDLEWARE, pool: "resources"),
      Route.new(verb: "POST", path: "/orders/:id/cancel",        handler: "cancel_order",     name: "cancel_order",     middleware: DEFAULT_MIDDLEWARE, pool: "resources"),
      Route.new(verb: "GET",  path: "/accounts/:id",             handler: "account",          name: "account",          middleware: DEFAULT_MIDDLEWARE, pool: "resources"),
      Route.new(verb: "GET",  path: "/inventory/:id",            handler: "inventory",        name: "inventory",        middleware: DEFAULT_MIDDLEWARE, pool: "resources"),
      Route.new(verb: "GET",  path: "/recommendations/:id",      handler: "recommendations",  name: "recommendations",  middleware: DEFAULT_MIDDLEWARE, pool: "resources"),
      Route.new(verb: "GET",  path: "/search",                   handler: "search",           name: "search",           middleware: DEFAULT_MIDDLEWARE, pool: "resources"),
      Route.new(verb: "POST", path: "/sessions",                 handler: "create_session",   name: "sessions",         middleware: DEFAULT_MIDDLEWARE, pool: "resources"),
      Route.new(verb: "GET",  path: "/profiles/:id/preferences", handler: "preferences",      name: "preferences",      middleware: DEFAULT_MIDDLEWARE, pool: "resources"),
      Route.new(verb: "GET",  path: "/healthz",                  handler: "health",           name: "health",           middleware: DEFAULT_MIDDLEWARE, pool: "system")
    ].freeze

    module_function

    def install_rails(router)
      TABLE.each do |route|
        router.public_send(
          route.verb.downcase,
          route.path,
          to: "resources#dispatch",
          defaults: { ores_handler: route.handler },
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

    def manifest
      TABLE.map do |route|
        {
          method: route.verb,
          path: route.path,
          handler: route.handler,
          name: route.name,
          middleware: route.middleware,
          pool: route.pool
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
