module OresApp
  module Routes
    Route = Struct.new(
      :method, :path, :name, :backend_path, :forward_query, :forward_body, :health,
      keyword_init: true
    )

    ROUTES = [
      Route.new(method: "GET",  path: "/users/:id",                name: "user",             backend_path: "/users/:id"),
      Route.new(method: "GET",  path: "/carts/:id",                name: "cart",             backend_path: "/carts/:id"),
      Route.new(method: "POST", path: "/checkout-sessions/:id",    name: "checkout_session", backend_path: "/checkout-sessions/:id", forward_body: true),
      Route.new(method: "GET",  path: "/products/:id",             name: "product",          backend_path: "/products/:id"),
      Route.new(method: "GET",  path: "/orders/:id",               name: "order",            backend_path: "/orders/:id"),
      Route.new(method: "POST", path: "/orders/:id/cancel",        name: "cancel_order",     backend_path: "/orders/:id/cancel", forward_body: true),
      Route.new(method: "GET",  path: "/accounts/:id",             name: "account",          backend_path: "/accounts/:id"),
      Route.new(method: "GET",  path: "/inventory/:id",            name: "inventory",        backend_path: "/inventory/:id"),
      Route.new(method: "GET",  path: "/recommendations/:id",      name: "recommendations",  backend_path: "/recommendations/:id", forward_query: true),
      Route.new(method: "GET",  path: "/search",                   name: "search",           backend_path: "/search", forward_query: true),
      Route.new(method: "POST", path: "/sessions",                 name: "sessions",         backend_path: "/sessions", forward_body: true),
      Route.new(method: "GET",  path: "/profiles/:id/preferences", name: "preferences",      backend_path: "/profiles/:id/preferences"),
      Route.new(method: "GET",  path: "/healthz",                  name: "health",           health: true)
    ].freeze

    module_function

    def each(&block)
      ROUTES.each(&block)
    end

    def match(method, path)
      verb = method.to_s.upcase
      candidate = path.to_s

      ROUTES.each do |route|
        next unless route.method == verb

        matched = compiled(route).match(candidate)
        next unless matched

        params = matched.names.each_with_object({}) { |name, memo| memo[name] = matched[name] }
        return [route, params]
      end

      nil
    end

    def expand(path_template, params)
      path_template.to_s.gsub(/:([a-z_][a-z0-9_]*)/i) do
        key = Regexp.last_match(1)
        value = params.fetch(key).to_s
        raise ArgumentError, "invalid route parameter #{key}" unless value.match?(/\A[A-Za-z0-9_-]{1,128}\z/)
        value
      end
    end

    def compiled(route)
      @compiled ||= {}
      @compiled[route.object_id] ||= begin
        pieces = route.path.split("/", -1).map do |segment|
          if segment.start_with?(":")
            name = segment.delete_prefix(":")
            "(?<#{name}>[A-Za-z0-9_-]{1,128})"
          else
            Regexp.escape(segment)
          end
        end
        Regexp.new("\\A#{pieces.join("/")}\\z")
      end
    end
  end
end
