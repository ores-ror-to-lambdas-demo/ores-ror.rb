# frozen_string_literal: true

require_relative "handlers"
require_relative "routes"

module OresApp
  module RouteHandlers
    module_function

    def call(route_or_name, request)
      handler_module(route_or_name).call(request)
    end

    def handler_module(route_or_name)
      route = resolve_route(route_or_name)
      handler_path = Routes.handler_path(route)
      raise LoadError, "missing route handler: #{Routes.handler_relative_path(route)}" unless File.file?(handler_path)

      require handler_path
      const_name = const_name(route.name)
      raise LoadError, "route handler #{Routes.handler_relative_path(route)} did not define OresApp::RouteHandlers::#{const_name}" unless const_defined?(const_name, false)

      const_get(const_name, false)
    end

    def validate!
      Routes::TABLE.each do |route|
        handler = handler_module(route)
        raise TypeError, "route handler #{Routes.handler_relative_path(route)} must respond to .call" unless handler.respond_to?(:call)
      end

      true
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
