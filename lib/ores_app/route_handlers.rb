# frozen_string_literal: true

require_relative "handlers"
require_relative "routes"

module OresApp
  module RouteHandlers
    module_function

    def call(route_or_name, request)
      route = resolve_route(route_or_name)
      handler_path = Routes.handler_path(route)
      raise LoadError, "missing route handler: #{Routes.handler_relative_path(route)}" unless File.file?(handler_path)

      require handler_path
      const_get(const_name(route.name), false).call(request)
    end

    def resolve_route(route_or_name)
      return route_or_name if route_or_name.is_a?(Routes::Route)

      Routes::TABLE.find { |route| route.name == route_or_name.to_s } ||
        raise(KeyError, "unknown route handler #{route_or_name.inspect}")
    end
    private_class_method :resolve_route

    def const_name(value)
      value.to_s.split(/[^A-Za-z0-9]+/).reject(&:empty?).map { |part| part[0].upcase + part[1..].to_s }.join
    end
    private_class_method :const_name
  end
end
