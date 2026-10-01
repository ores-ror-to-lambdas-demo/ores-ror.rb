# frozen_string_literal: true

require "uri"

module OresApp
  module Routes
    Route = Struct.new(
      :verb, :path, :handler, :name, :middleware, :group, :pool,
      :controller, :action, :view,
      keyword_init: true
    )

    DEFAULT_MIDDLEWARE = %w[request_id].freeze

    TABLE = [
      Route.new(verb: "GET",  path: "/users/:id",                handler: "user",             name: "user",             middleware: DEFAULT_MIDDLEWARE, group: "users",           pool: "users",           controller: "users",             action: "show",        view: "users/show"),
      Route.new(verb: "GET",  path: "/carts/:id",                handler: "cart",             name: "cart",             middleware: DEFAULT_MIDDLEWARE, group: "carts",           pool: "carts",           controller: "carts",             action: "show",        view: "carts/show"),
      Route.new(verb: "POST", path: "/checkout-sessions/:id",    handler: "checkout_session", name: "checkout_session", middleware: DEFAULT_MIDDLEWARE, group: "checkout",        pool: "checkout",        controller: "checkout_sessions", action: "create",      view: "checkout_sessions/create"),
      Route.new(verb: "GET",  path: "/products/:id",             handler: "product",          name: "product",          middleware: DEFAULT_MIDDLEWARE, group: "products",        pool: "products",        controller: "products",          action: "show",        view: "products/show"),
      Route.new(verb: "GET",  path: "/orders/:id",               handler: "order",            name: "order",            middleware: DEFAULT_MIDDLEWARE, group: "orders",          pool: "orders",          controller: "orders",            action: "show",        view: "orders/show"),
      Route.new(verb: "POST", path: "/orders/:id/cancel",        handler: "cancel_order",     name: "cancel_order",     middleware: DEFAULT_MIDDLEWARE, group: "orders",          pool: "orders",          controller: "orders",            action: "cancel",      view: "orders/cancel"),
      Route.new(verb: "GET",  path: "/accounts/:id",             handler: "account",          name: "account",          middleware: DEFAULT_MIDDLEWARE, group: "accounts",        pool: "accounts",        controller: "accounts",          action: "show",        view: "accounts/show"),
      Route.new(verb: "GET",  path: "/inventory/:id",            handler: "inventory",        name: "inventory",        middleware: DEFAULT_MIDDLEWARE, group: "inventory",       pool: "inventory",       controller: "inventory",         action: "show",        view: "inventory/show"),
      Route.new(verb: "GET",  path: "/recommendations/:id",      handler: "recommendations",  name: "recommendations",  middleware: DEFAULT_MIDDLEWARE, group: "recommendations", pool: "recommendations", controller: "recommendations",   action: "show",        view: "recommendations/show"),
      Route.new(verb: "GET",  path: "/search",                   handler: "search",           name: "search",           middleware: DEFAULT_MIDDLEWARE, group: "search",          pool: "search",          controller: "search",            action: "index",       view: "search/index"),
      Route.new(verb: "POST", path: "/sessions",                 handler: "create_session",   name: "sessions",         middleware: DEFAULT_MIDDLEWARE, group: "sessions",        pool: "sessions",        controller: "sessions",          action: "create",      view: "sessions/create"),
      Route.new(verb: "GET",  path: "/profiles/:id/preferences", handler: "preferences",      name: "preferences",      middleware: DEFAULT_MIDDLEWARE, group: "profiles",        pool: "profiles",        controller: "profiles",          action: "preferences", view: "profiles/preferences"),
      Route.new(verb: "GET",  path: "/healthz",                  handler: "health",           name: "health",           middleware: DEFAULT_MIDDLEWARE, group: "system",          pool: "system",          controller: "health",            action: "show",        view: "health/show")
    ].freeze

    module_function

    def install_rails(router)
      TABLE.each do |route|
        router.public_send(route.verb.downcase, route.path, to: "#{route.controller}##{route.action}", as: route.name.to_sym)
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

    def for_controller_action(controller, action)
      TABLE.find { |route| route.controller == controller.to_s && route.action == action.to_s }
    end

    def lambda_route_relative_path(route)
      segments = route.path.split("/").reject(&:empty?).map { |segment| filesystem_segment(segment) }
      File.join(*segments, "handler.rb")
    end

    def rails_controller_class_name(route)
      classify(route.controller) + "Controller"
    end

    def plain_controller_class_name(route)
      "OresApp::Controllers::#{classify(route.controller)}"
    end

    def controller_source_path(route)
      File.expand_path("../../app/controllers/#{route.controller}_controller.rb", __dir__)
    end

    def view_source_path(route)
      File.expand_path("../../app/views/#{route.view}.json.erb", __dir__)
    end

    def manifest
      TABLE.map do |route|
        {
          method: route.verb, path: route.path, handler: route.handler, name: route.name,
          middleware: route.middleware, group: route.group, pool: route.pool,
          rails_controller: rails_controller_class_name(route), controller: route.controller,
          plain_controller: plain_controller_class_name(route), action: route.action, view: route.view,
          route_handler: "generated/lambda/routes/#{lambda_route_relative_path(route)}"
        }
      end
    end

    def route_pattern(path)
      pieces = path.split("/", -1).map do |piece|
        piece.start_with?(":") ? "(?<#{piece.delete_prefix(":")}>[^/]+)" : Regexp.escape(piece)
      end
      Regexp.new("\\A#{pieces.join("/")}\\z")
    end
    private_class_method :route_pattern

    def filesystem_segment(segment)
      segment.start_with?(":") ? "[#{segment.delete_prefix(":")}]" : segment
    end
    private_class_method :filesystem_segment

    def classify(value)
      value.split("/").map { |part| part.split("_").map { |token| token[0].upcase + token[1..].to_s }.join }.join("::")
    end
    private_class_method :classify
  end
end
