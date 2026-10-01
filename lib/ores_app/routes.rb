# frozen_string_literal: true

require "uri"

module OresApp
  module Routes
    Route = Struct.new(:verb, :path, :handler, :name, :middleware, :group, :pool, keyword_init: true)

    DEFAULT_MIDDLEWARE = %w[request_id].freeze

    TABLE = [
      Route.new(verb: "GET",  path: "/users/:id",                handler: "user",             name: "user",             middleware: DEFAULT_MIDDLEWARE, group: "users",            pool: "users"),
      Route.new(verb: "GET",  path: "/carts/:id",                handler: "cart",             name: "cart",             middleware: DEFAULT_MIDDLEWARE, group: "carts",            pool: "carts"),
      Route.new(verb: "POST", path: "/checkout-sessions/:id",    handler: "checkout_session", name: "checkout_session", middleware: DEFAULT_MIDDLEWARE, group: "checkout",         pool: "checkout"),
      Route.new(verb: "GET",  path: "/products/:id",             handler: "product",          name: "product",          middleware: DEFAULT_MIDDLEWARE, group: "products",         pool: "products"),
      Route.new(verb: "GET",  path: "/orders/:id",               handler: "order",            name: "order",            middleware: DEFAULT_MIDDLEWARE, group: "orders",           pool: "orders"),
      Route.new(verb: "POST", path: "/orders/:id/cancel",        handler: "cancel_order",     name: "cancel_order",     middleware: DEFAULT_MIDDLEWARE, group: "orders",           pool: "orders"),
      Route.new(verb: "GET",  path: "/accounts/:id",             handler: "account",          name: "account",          middleware: DEFAULT_MIDDLEWARE, group: "accounts",         pool: "accounts"),
      Route.new(verb: "GET",  path: "/inventory/:id",            handler: "inventory",        name: "inventory",        middleware: DEFAULT_MIDDLEWARE, group: "inventory",        pool: "inventory"),
      Route.new(verb: "GET",  path: "/recommendations/:id",      handler: "recommendations",  name: "recommendations",  middleware: DEFAULT_MIDDLEWARE, group: "recommendations",  pool: "recommendations"),
      Route.new(verb: "GET",  path: "/search",                   handler: "search",           name: "search",           middleware: DEFAULT_MIDDLEWARE, group: "search",           pool: "search"),
      Route.new(verb: "POST", path: "/sessions",                 handler: "create_session",   name: "sessions",         middleware: DEFAULT_MIDDLEWARE, group: "sessions",         pool: "sessions"),
      Route.new(verb: "GET",  path: "/profiles/:id/preferences", handler: "preferences",      name: "preferences",      middleware: DEFAULT_MIDDLEWARE, group: "profiles",         pool: "profiles"),
      Route.new(verb: "GET",  path: "/healthz",                  handler: "health",           name: "health",           middleware: DEFAULT_MIDDLEWARE, group: "system",           pool: "system")
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

    def handler_relative_path(route)
      segments = route.path.split("/").reject(&:empty?).map { |segment| filesystem_segment(segment) }
      File.join("routes", *segments, "handler.rb")
    end

    def handler_path(route)
      File.join(root_path, handler_relative_path(route))
    end

    def root_path
      File.expand_path("../..", __dir__)
    end

    def filesystem_handler_paths
      Dir.glob(File.join(root_path, "routes", "**", "handler.rb")).sort.map do |path|
        path.delete_prefix("#{root_path}/")
      end
    end

    def validate!
      errors = []

      duplicate_route_keys = TABLE.group_by { |route| [route.verb, route.path] }.select { |_key, routes| routes.length > 1 }.keys
      errors << "duplicate verb/path entries: #{duplicate_route_keys.map { |verb, path| "#{verb} #{path}" }.join(", ")}" unless duplicate_route_keys.empty?

      duplicate_names = TABLE.group_by(&:name).select { |_name, routes| routes.length > 1 }.keys
      errors << "duplicate route names: #{duplicate_names.join(", ")}" unless duplicate_names.empty?

      expected_handlers = TABLE.map { |route| handler_relative_path(route) }.sort
      missing_handlers = expected_handlers.reject { |path| File.file?(File.join(root_path, path)) }
      orphan_handlers = filesystem_handler_paths - expected_handlers

      errors << "missing filesystem handlers: #{missing_handlers.join(", ")}" unless missing_handlers.empty?
      errors << "orphan filesystem handlers: #{orphan_handlers.join(", ")}" unless orphan_handlers.empty?

      raise ArgumentError, "invalid route contract:\n- #{errors.join("\n- ")}" unless errors.empty?

      true
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
          source_handler: handler_relative_path(route)
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

    def filesystem_segment(segment)
      return "[#{segment.delete_prefix(":")}]" if segment.start_with?(":")

      segment
    end
    private_class_method :filesystem_segment
  end
end
