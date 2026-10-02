# frozen_string_literal: true

require "digest"
require "pathname"
require "ripper"
require_relative "../ores_app/routes"
require_relative "../ores_app/middleware"

module OresBuild
  class StaticRoutes
    HTTP_VERBS = %w[get post put patch delete options head].freeze
    RESOURCE_ACTIONS = %w[index create new show edit update destroy].freeze
    SINGLETON_ACTIONS = %w[new create show edit update destroy].freeze
    ROUTE_ANNOTATION = /^\s*#\s*ores-route:\s*(GET|POST|PUT|PATCH|DELETE|OPTIONS|HEAD)\s+(\S+)\s+action=([A-Za-z_][A-Za-z0-9_]*)\s*$/i.freeze

    Context = Struct.new(:path_prefix, :module_prefix, :as_prefix, :group, :parent_resource, keyword_init: true)

    def initialize(root)
      @root = Pathname(root).realpath
      @routes_file = @root.join("config/routes.rb")
      @routes = []
    end

    def compile
      source = read_confined!(@routes_file, "routes authority")
      sexp = Ripper.sexp(source)
      fail! "cannot parse #{@routes_file}" unless sexp
      draw = find_draw_block(sexp)
      fail! "config/routes.rb must contain Rails.application.routes.draw do ... end" unless draw

      process_body(block_body(draw), Context.new(path_prefix: "", module_prefix: "", as_prefix: "", group: nil, parent_resource: nil))
      validate_unique!
      @routes
    end

    private

    def find_draw_block(node)
      return unless node.is_a?(Array)
      if node[0] == :method_add_block && call_name(node[1]) == "draw"
        return node[2]
      end
      node.each do |child|
        next unless child.is_a?(Array)
        found = find_draw_block(child)
        return found if found
      end
      nil
    end

    def block_body(block)
      fail! "route DSL block is malformed" unless block.is_a?(Array)
      case block[0]
      when :do_block
        block[2]
      when :brace_block
        [:bodystmt, block[2], nil, nil, nil]
      else
        fail! "unsupported route block #{block[0].inspect}"
      end
    end

    def statements(body)
      return [] if body.nil?
      return body[1] || [] if body.is_a?(Array) && body[0] == :bodystmt
      return body[1] || [] if body.is_a?(Array) && body[0] == :program
      Array(body)
    end

    def process_body(body, context)
      statements(body).each do |statement|
        next unless statement.is_a?(Array)
        if statement[0] == :void_stmt
          next
        elsif statement[0] == :method_add_block
          process_block_call(statement, context)
        else
          process_call(statement, context)
        end
      end
    end

    def process_block_call(node, context)
      call = parse_call(node[1])
      fail! "unsupported dynamic route block" unless call
      name, args, line = call
      child_body = block_body(node[2])

      case name
      when "namespace"
        ns = literal_name(args[0], line)
        options = options_from(args.drop(1))
        path_part = options.fetch("path", ns)
        module_part = options.fetch("module", ns)
        as_part = options.fetch("as", ns)
        child = Context.new(
          path_prefix: join_paths(context.path_prefix, path_part),
          module_prefix: join_modules(context.module_prefix, module_part),
          as_prefix: join_names(context.as_prefix, as_part),
          group: context.group || ns,
          parent_resource: context.parent_resource
        )
        process_body(child_body, child)
      when "scope"
        positional = args.reject { |arg| hash_node?(arg) }
        options = options_from(args)
        path_part = options["path"] || (positional[0] && static_value(positional[0])) || ""
        module_part = options.fetch("module", "")
        as_part = options.fetch("as", "")
        child = Context.new(
          path_prefix: join_paths(context.path_prefix, path_part.to_s),
          module_prefix: join_modules(context.module_prefix, module_part.to_s),
          as_prefix: join_names(context.as_prefix, as_part.to_s),
          group: context.group,
          parent_resource: context.parent_resource
        )
        process_body(child_body, child)
      when "resources"
        resource_name = literal_name(args[0], line)
        options = options_from(args.drop(1))
        add_resources(resource_name, options, context, line)
        nested = nested_resource_context(resource_name, options, context)
        process_body(child_body, nested)
      when "resource"
        resource_name = literal_name(args[0], line)
        options = options_from(args.drop(1))
        add_resource(resource_name, options, context, line)
        nested = singleton_resource_context(resource_name, options, context)
        process_body(child_body, nested)
      else
        fail! "unsupported block route DSL #{name.inspect} at line #{line || '?'}"
      end
    end

    def process_call(node, context)
      call = parse_call(node)
      return if call.nil?
      name, args, line = call

      if HTTP_VERBS.include?(name)
        add_explicit_route(name, args, context, line)
      elsif name == "resources"
        resource_name = literal_name(args[0], line)
        add_resources(resource_name, options_from(args.drop(1)), context, line)
      elsif name == "resource"
        resource_name = literal_name(args[0], line)
        add_resource(resource_name, options_from(args.drop(1)), context, line)
      elsif %w[root match mount concern concerns direct resolve member collection controller].include?(name)
        fail! "unsupported route DSL #{name.inspect} at line #{line || '?'}"
      else
        fail! "unsupported expression in config/routes.rb: #{name.inspect} at line #{line || '?'}"
      end
    end

    def add_explicit_route(verb, args, context, line)
      positional = args.reject { |arg| hash_node?(arg) }
      raw_path = static_value(positional[0])
      options = options_from(args)
      fail! "#{verb.upcase} at line #{line || '?'} requires a literal path" unless raw_path.is_a?(String)

      target = options["to"]
      controller = options["controller"]
      action = options["action"]
      if target
        fail! "route target at line #{line || '?'} must be controller#action" unless target.is_a?(String) && target.include?("#")
        controller, action = target.split("#", 2)
      end
      fail! "#{verb.upcase} at line #{line || '?'} requires to: \"controller#action\" or controller:/action:" unless controller && action

      controller = join_modules(context.module_prefix, controller)
      path = join_paths(context.path_prefix, raw_path)
      explicit_name = options["as"]
      name = explicit_name ? join_names(context.as_prefix, explicit_name.to_s) : generated_name(verb, path, controller, action)
      add_route(
        verb.upcase,
        path,
        controller,
        action.to_s,
        name,
        context.group,
        middleware: middleware_from_options(options)
      )
    end

    def add_resources(name, options, context, line)
      only = action_filter(options, RESOURCE_ACTIONS, line)
      singular = singularize(name)
      path_part = options.fetch("path", name).to_s
      controller = join_modules(context.module_prefix, options.fetch("controller", name).to_s)
      base_path = join_paths(context.path_prefix, path_part)
      base_name = join_names(context.as_prefix, options.fetch("as", singular).to_s)
      member_path = join_paths(base_path, ":id")

      add_route("GET", base_path, controller, "index", plural_name(base_name), context.group || top_group(controller)) if only.include?("index")
      add_route("POST", base_path, controller, "create", plural_name(base_name), context.group || top_group(controller)) if only.include?("create")
      add_route("GET", join_paths(base_path, "new"), controller, "new", join_names("new", base_name), context.group || top_group(controller)) if only.include?("new")
      add_route("GET", member_path, controller, "show", base_name, context.group || top_group(controller)) if only.include?("show")
      add_route("GET", join_paths(member_path, "edit"), controller, "edit", join_names("edit", base_name), context.group || top_group(controller)) if only.include?("edit")
      if only.include?("update")
        add_route("PATCH", member_path, controller, "update", base_name, context.group || top_group(controller), duplicate_name_ok: true)
        add_route("PUT", member_path, controller, "update", base_name, context.group || top_group(controller), duplicate_name_ok: true)
      end
      add_route("DELETE", member_path, controller, "destroy", base_name, context.group || top_group(controller), duplicate_name_ok: true) if only.include?("destroy")
    end

    def add_resource(name, options, context, line)
      only = action_filter(options, SINGLETON_ACTIONS, line)
      path_part = options.fetch("path", name).to_s
      controller_name = options.fetch("controller", pluralize(name)).to_s
      controller = join_modules(context.module_prefix, controller_name)
      base_path = join_paths(context.path_prefix, path_part)
      base_name = join_names(context.as_prefix, options.fetch("as", name).to_s)

      add_route("GET", join_paths(base_path, "new"), controller, "new", join_names("new", base_name), context.group || top_group(controller)) if only.include?("new")
      add_route("POST", base_path, controller, "create", base_name, context.group || top_group(controller), duplicate_name_ok: true) if only.include?("create")
      add_route("GET", base_path, controller, "show", base_name, context.group || top_group(controller), duplicate_name_ok: true) if only.include?("show")
      add_route("GET", join_paths(base_path, "edit"), controller, "edit", join_names("edit", base_name), context.group || top_group(controller)) if only.include?("edit")
      if only.include?("update")
        add_route("PATCH", base_path, controller, "update", base_name, context.group || top_group(controller), duplicate_name_ok: true)
        add_route("PUT", base_path, controller, "update", base_name, context.group || top_group(controller), duplicate_name_ok: true)
      end
      add_route("DELETE", base_path, controller, "destroy", base_name, context.group || top_group(controller), duplicate_name_ok: true) if only.include?("destroy")
    end

    def nested_resource_context(name, options, context)
      path_part = options.fetch("path", name).to_s
      singular = singularize(name)
      Context.new(
        path_prefix: join_paths(context.path_prefix, path_part, ":#{singular}_id"),
        module_prefix: context.module_prefix,
        as_prefix: join_names(context.as_prefix, singular),
        group: context.group || name,
        parent_resource: singular
      )
    end

    def singleton_resource_context(name, options, context)
      Context.new(
        path_prefix: join_paths(context.path_prefix, options.fetch("path", name).to_s),
        module_prefix: context.module_prefix,
        as_prefix: join_names(context.as_prefix, name),
        group: context.group || name,
        parent_resource: name
      )
    end

    def action_filter(options, defaults, line)
      only = Array(options["only"] || defaults).map(&:to_s)
      except = Array(options["except"]).map(&:to_s)
      unknown = (only + except).uniq - defaults
      fail! "unsupported resource actions #{unknown.inspect} at line #{line || '?'}" unless unknown.empty?
      only - except
    end

    def add_route(verb, path, controller, action, name, group, middleware: nil, duplicate_name_ok: false)
      controller_file = controller_file_for(controller)
      fail! "Rails convention expected controller file #{relative(controller_file)}" unless controller_file.file?
      controller_file = confined_file!(controller_file, "controller source")
      fail! "Rails convention expected #{controller}##{action} in #{relative(controller_file)}" unless source_defines_action?(controller_file, action)

      annotations = controller_route_annotations(controller_file)
      normalized_path = normalize_path(path)
      annotation = annotations.find do |entry|
        entry.fetch(:verb) == verb &&
          entry.fetch(:path) == normalized_path &&
          entry.fetch(:action) == action.to_s
      end
      if annotations.any? && annotation.nil?
        expected = "# ores-route: #{verb} #{normalized_path} action=#{action}"
        fail! "controller route annotations in #{relative(controller_file)} do not declare #{expected}"
      end

      group_name = group || top_group(controller)
      model_token = model_token_for(controller)
      model_class = camelize(model_token)
      model_file = @root.join("app/models/#{model_token}.rb")
      fail! "Rails convention expected model file #{relative(model_file)}" unless model_file.file?
      model_file = confined_file!(model_file, "model source")
      fail! "Rails convention expected model class #{model_class} in #{relative(model_file)}" unless source_defines_class?(model_file, model_class)

      view_files = Dir.glob(@root.join("app/views", controller, "#{action}.*").to_s).sort.map do |file|
        relative(confined_file!(Pathname(file), "view source"))
      end
      fail! "Rails convention expected a view for #{controller}##{action}" if view_files.empty?
      %w[json html].each do |format|
        fail! "Rails-free runtime requires a .#{format}.erb view for #{controller}##{action}" unless view_files.any? { |file| file.end_with?(".#{format}.erb") }
      end

      route = {
        verb: verb,
        path: normalize_path(path),
        name: name,
        controller: controller,
        controller_class: controller_class_name(controller),
        action: action,
        controller_file: relative(controller_file),
        controller_route_annotation: annotation && annotation.fetch(:declaration),
        controller_route_annotated: !annotation.nil?,
        model_class: model_class,
        model_file: relative(model_file),
        view_logical_path: "#{controller}/#{action}",
        view_files: view_files,
        middleware: OresApp::Middleware.normalize_names(middleware || OresApp::Routes::DEFAULT_MIDDLEWARE),
        group: group_name,
        pool: group_name,
        route_key: "#{verb} #{normalize_path(path)}"
      }
      route[:name] = generated_name(verb, route[:path], controller, action) if route[:name].nil? || route[:name].empty?
      route[:duplicate_name_ok] = duplicate_name_ok
      @routes << route
    end

    def controller_file_for(controller)
      direct = @root.join("app/controllers/#{controller}_controller.rb")
      return direct if direct.file?
      endpoint = @root.join("app/controllers/#{controller}/endpoint_controller.rb")
      return endpoint if endpoint.file?
      direct
    end

    def controller_route_annotations(file)
      read_confined!(file, "controller source").each_line.filter_map do |line|
        next unless line.match?(/^\s*#\s*ores-route:/i)

        match = ROUTE_ANNOTATION.match(line)
        fail! "malformed ores-route annotation in #{relative(file)}: #{line.strip.inspect}" unless match

        {
          verb: match[1].upcase,
          path: normalize_path(match[2]),
          action: match[3],
          declaration: "# ores-route: #{match[1].upcase} #{normalize_path(match[2])} action=#{match[3]}"
        }
      end
    end

    def source_defines_action?(file, action)
      sexp = Ripper.sexp(read_confined!(file, "controller source"))
      return false unless sexp
      found = false
      walk(sexp) do |node|
        next unless node[0] == :def
        ident = node[1]
        if ident.is_a?(Array) && ident[0] == :@ident && ident[1] == action
          found = true
          break
        end
      end
      found
    end

    def source_defines_class?(file, class_name)
      read_confined!(file, "model source").match?(/^\s*class\s+#{Regexp.escape(class_name)}\b/)
    end

    def validate_unique!
      dup_routes = @routes.group_by { |route| route[:route_key] }.select { |_key, rows| rows.length > 1 }
      fail! "duplicate routes: #{dup_routes.keys.join(', ')}" unless dup_routes.empty?

      dup_names = @routes.group_by { |route| route[:name] }.select do |_name, rows|
        rows.length > 1 && rows.map { |row| row[:path] }.uniq.length > 1
      end
      fail! "duplicate route names with different paths: #{dup_names.keys.join(', ')}" unless dup_names.empty?
      @routes.each { |route| route.delete(:duplicate_name_ok) }
    end

    def parse_call(node)
      return unless node.is_a?(Array)
      case node[0]
      when :command
        ident = node[1]
        return unless ident&.[](0) == :@ident
        [ident[1], argument_nodes(node[2]), ident[2]&.first]
      when :method_add_arg
        callee = node[1]
        name = call_name(callee)
        return unless name
        args_node = node[2]
        args_node = args_node[1] if args_node&.[](0) == :arg_paren
        [name, argument_nodes(args_node), call_line(callee)]
      when :fcall, :vcall
        ident = node[1]
        return unless ident&.[](0) == :@ident
        [ident[1], [], ident[2]&.first]
      end
    end

    def call_name(node)
      return unless node.is_a?(Array)
      case node[0]
      when :fcall, :vcall
        node.dig(1, 1)
      when :call
        node.dig(3, 1)
      when :command
        node.dig(1, 1)
      when :method_add_arg
        call_name(node[1])
      end
    end

    def call_line(node)
      return unless node.is_a?(Array)
      ident = case node[0]
              when :fcall, :vcall then node[1]
              when :call then node[3]
              when :method_add_arg then return call_line(node[1])
              end
      ident&.[](2)&.first
    end

    def argument_nodes(args_node)
      return [] unless args_node.is_a?(Array)
      return args_node[1] || [] if args_node[0] == :args_add_block
      []
    end

    def middleware_from_options(options)
      defaults = options["defaults"]
      configured = defaults.is_a?(Hash) ? defaults["ores_middleware"] : nil
      OresApp::Middleware.normalize_names(configured || OresApp::Routes::DEFAULT_MIDDLEWARE)
    end

    def options_from(args)
      args.select { |arg| hash_node?(arg) }.each_with_object({}) do |arg, out|
        out.merge!(static_hash(arg))
      end
    end

    def hash_node?(node)
      node.is_a?(Array) && %i[bare_assoc_hash hash].include?(node[0])
    end

    def static_hash(node)
      pairs = case node[0]
              when :bare_assoc_hash then node[1] || []
              when :hash
                assoc = node[1]
                assoc&.[](0) == :assoclist_from_args ? (assoc[1] || []) : []
              else []
              end
      pairs.each_with_object({}) do |pair, out|
        fail! "dynamic hash option in routes" unless pair.is_a?(Array) && pair[0] == :assoc_new
        key_node, value_node = pair[1], pair[2]
        key = if key_node&.[](0) == :@label
                key_node[1].delete_suffix(":")
              else
                static_value(key_node).to_s
              end
        out[key] = static_value(value_node)
      end
    end

    def static_value(node)
      return nil if node.nil?
      return node unless node.is_a?(Array)
      case node[0]
      when :string_literal
        content = node[1]
        return "" if content == [:string_content]
        fail! "dynamic string in routes" unless content&.[](0) == :string_content
        pieces = content.drop(1)
        fail! "interpolated strings are not allowed in routes" unless pieces.all? { |piece| piece.is_a?(Array) && piece[0] == :@tstring_content }
        pieces.map { |piece| piece[1] }.join
      when :symbol_literal
        symbol = node.dig(1, 1)
        fail! "dynamic symbol in routes" unless symbol.is_a?(Array)
        symbol[1]
      when :array
        Array(node[1]).map { |entry| static_value(entry) }
      when :var_ref
        token = node[1]
        case token&.[](0)
        when :@kw
          {"true" => true, "false" => false, "nil" => nil}.fetch(token[1]) { fail! "unsupported keyword #{token[1]} in routes" }
        when :@const
          token[1]
        else
          fail! "dynamic variable in routes"
        end
      when :@int
        Integer(node[1])
      when :@ident, :@const
        node[1]
      when :hash, :bare_assoc_hash
        static_hash(node)
      else
        fail! "unsupported dynamic route value #{node[0].inspect}"
      end
    end

    def literal_name(node, line)
      value = static_value(node)
      fail! "route DSL at line #{line || '?'} requires a literal symbol/string name" unless value.is_a?(String) && !value.empty?
      value
    end

    def walk(node, &block)
      return unless node.is_a?(Array)
      yield node
      node.each { |child| walk(child, &block) if child.is_a?(Array) }
    end

    def controller_class_name(controller)
      controller.split("/").map { |part| camelize(part) }.join("::") + "Controller"
    end

    def camelize(value)
      value.split("_").map { |part| part[0].to_s.upcase + part[1..].to_s }.join
    end

    def singularize(value)
      value = value.to_s
      return value[0...-3] + "y" if value.end_with?("ies")
      return value[0...-1] if value.end_with?("s") && !value.end_with?("ss")
      value
    end

    def model_token_for(controller)
      pieces = controller.to_s.split("/")
      resource = pieces.last == "endpoint" ? pieces.first : pieces.last
      singular = singularize(resource)
      singular == resource ? "#{resource}_record" : singular
    end

    def pluralize(value)
      value = value.to_s
      return value if value.end_with?("s")
      return value[0...-1] + "ies" if value.end_with?("y")
      value + "s"
    end

    def plural_name(name)
      pluralize(name)
    end

    def top_group(controller)
      controller.split("/").first
    end

    def join_modules(*parts)
      parts.flat_map { |part| part.to_s.split("/") }.reject(&:empty?).join("/")
    end

    def join_names(*parts)
      parts.map(&:to_s).reject(&:empty?).join("_")
    end

    def join_paths(*parts)
      clean = parts.map(&:to_s).reject(&:empty?).map { |part| part.gsub(%r{\A/+|/+$}, "") }.reject(&:empty?)
      "/" + clean.join("/")
    end

    def normalize_path(path)
      result = path.to_s.gsub(%r{/+}, "/")
      result = "/#{result}" unless result.start_with?("/")
      result.length > 1 ? result.delete_suffix("/") : result
    end

    def generated_name(verb, path, controller, action)
      "rails_#{Digest::SHA256.hexdigest("#{verb} #{path} #{controller}##{action}")[0, 12]}"
    end

    def confined_file!(path, label)
      path = Pathname(path)
      relative_path = path.relative_path_from(@root)
      fail! "#{label} escapes application root: #{path}" if relative_path.to_s.start_with?("../")

      cursor = @root
      relative_path.each_filename do |segment|
        cursor = cursor.join(segment)
        begin
          stat = File.lstat(cursor.to_s)
        rescue Errno::ENOENT
          fail! "#{label} does not exist: #{relative_path}"
        end
        fail! "#{label} contains a symlink: #{relative_path}" if stat.symlink?
      end

      resolved = path.realpath
      root_prefix = @root.to_s + File::SEPARATOR
      fail! "#{label} escapes application root: #{relative_path}" unless resolved.to_s.start_with?(root_prefix)
      fail! "#{label} is not a regular file: #{relative_path}" unless resolved.file?
      resolved
    rescue ArgumentError
      fail! "#{label} escapes application root: #{path}"
    end

    def read_confined!(path, label)
      confined_file!(path, label).read
    end

    def relative(path)
      Pathname(path).relative_path_from(@root).to_s
    end

    def fail!(message)
      raise ArgumentError, message
    end
  end
end
