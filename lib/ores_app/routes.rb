# frozen_string_literal: true

require "uri"
require_relative "route_handlers"

module OresApp
  module Routes
    DEFAULT_MIDDLEWARE = %w[request_id].freeze
    FILESYSTEM_AVAILABLE = !(defined?(ORES_GRAAL_RUNTIME) && ORES_GRAAL_RUNTIME)
    REPO_ROOT = FILESYSTEM_AVAILABLE ? File.expand_path("../..", __dir__) : nil
    ROUTES_ROOT = REPO_ROOT && File.join(REPO_ROOT, "routes")

    Route = Struct.new(
      :verb, :path, :handler, :name, :middleware, :group, :pool, :source, :callable,
      keyword_init: true
    ) do
      def call(request)
        callable.call(request)
      end
    end

    GroupHandler = Struct.new(:name, :source, :callable, keyword_init: true) do
      def call(route, request)
        callable.call(route, request)
      end
    end

    TABLE = []
    GROUP_HANDLERS = {}

    module_function

    def register(verb:, name:, group:, pool:, source:, handler: nil, middleware: DEFAULT_MIDDLEWARE, &callable)
      raise ArgumentError, "route handler block is required" unless callable

      source = normalize_source(source)
      path = path_from_source(source)
      verb = verb.to_s.upcase
      name = name.to_s
      handler = (handler || name).to_s
      group = group.to_s
      pool = pool.to_s

      raise ArgumentError, "duplicate route name #{name.inspect}" if TABLE.any? { |route| route.name == name }
      if TABLE.any? { |route| route.verb == verb && route.path == path }
        raise ArgumentError, "duplicate route #{verb} #{path}"
      end

      Route.new(
        verb: verb,
        path: path,
        handler: handler,
        name: name,
        middleware: Array(middleware).map(&:to_s).freeze,
        group: group,
        pool: pool,
        source: source,
        callable: callable
      ).tap { |route| TABLE << route }
    end

    def register_group(name:, source:, &callable)
      raise ArgumentError, "group handler block is required" unless callable

      name = name.to_s
      source = normalize_source(source)
      raise ArgumentError, "duplicate group handler #{name.inspect}" if GROUP_HANDLERS.key?(name)

      GROUP_HANDLERS[name] = GroupHandler.new(name: name, source: source, callable: callable)
    end

    def load_files!
      return TABLE if @filesystem_loaded
      raise "filesystem route discovery is unavailable in this runtime" unless ROUTES_ROOT

      files = Dir.glob(File.join(ROUTES_ROOT, "**", "handler.rb")).sort
      raise "no physical route handlers found under #{ROUTES_ROOT}" if files.empty?
      files.each { |file| require file }
      validate_filesystem!(files)
      @filesystem_loaded = true
      TABLE
    end

    def install_rails(router)
      load_files!
      TABLE.each do |route|
        router.public_send(
          route.verb.downcase,
          route.path,
          to: "resources#handle",
          defaults: { ores_handler: route.handler },
          as: route.name.to_sym
        )
      end
    end

    def match(method, path)
      load_files_if_needed!
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

    def fetch(name)
      load_files_if_needed!
      TABLE.find { |route| route.name == name.to_s || route.handler == name.to_s } ||
        raise(KeyError, "unknown route handler #{name.inspect}")
    end

    def invoke_group(name, route, request)
      group_handler = GROUP_HANDLERS[name.to_s]
      return group_handler.call(route, request) if group_handler

      route.call(request)
    end

    def handler_relative_path(route)
      route.source
    end

    def handler_path(route)
      raise "filesystem route access is unavailable in this runtime" unless REPO_ROOT
      File.join(REPO_ROOT, route.source)
    end

    def manifest
      load_files_if_needed!
      TABLE.map do |route|
        {
          method: route.verb,
          path: route.path,
          handler: route.handler,
          name: route.name,
          middleware: route.middleware,
          group: route.group,
          pool: route.pool,
          source_handler: route.source
        }
      end
    end

    def source_files(include_groups: true)
      load_files_if_needed!
      sources = TABLE.map(&:source)
      sources.concat(GROUP_HANDLERS.values.map(&:source)) if include_groups
      sources.uniq.sort
    end

    def path_from_source(source)
      source = normalize_source(source)
      match = %r{\Aroutes/(.+)/handler\.rb\z}.match(source)
      raise ArgumentError, "route source must be routes/**/handler.rb: #{source.inspect}" unless match

      segments = match[1].split("/").map do |segment|
        dynamic = /\A\[([a-z_][a-z0-9_]*)\]\z/i.match(segment)
        next ":#{dynamic[1]}" if dynamic

        unless segment.match?(/\A[A-Za-z0-9._-]+\z/)
          raise ArgumentError, "invalid route filesystem segment #{segment.inspect}"
        end
        segment
      end
      "/#{segments.join("/")}"
    end

    def validate_filesystem!(files = nil)
      raise "filesystem route validation is unavailable in this runtime" unless ROUTES_ROOT

      files ||= Dir.glob(File.join(ROUTES_ROOT, "**", "handler.rb")).sort
      actual = files.map { |file| relative_source(file) }.sort
      registered = (TABLE.map(&:source) + GROUP_HANDLERS.values.map(&:source)).uniq.sort
      unregistered = actual - registered
      missing = registered - actual

      raise "unregistered physical route handlers: #{unregistered.join(", ")}" unless unregistered.empty?
      raise "registered handlers missing from filesystem: #{missing.join(", ")}" unless missing.empty?

      TABLE.each do |route|
        derived = path_from_source(route.source)
        raise "route/source mismatch for #{route.name}: #{route.path} != #{derived}" unless route.path == derived
      end
      true
    end

    def normalize_source(source)
      source.to_s.tr("\\", "/").sub(%r{\A\./}, "")
    end
    private_class_method :normalize_source

    def relative_source(file)
      file.sub(%r{\A#{Regexp.escape(REPO_ROOT)}/?}, "").tr("\\", "/")
    end
    private_class_method :relative_source

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

    def load_files_if_needed!
      return unless TABLE.empty?
      load_files!
    end
    private_class_method :load_files_if_needed!
  end
end
