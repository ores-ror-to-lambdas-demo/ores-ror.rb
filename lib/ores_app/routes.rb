# frozen_string_literal: true

require "uri"

module OresApp
  module Routes
    Route = Struct.new(
      :verb, :path, :name, :controller, :action, :middleware, :group, :pool, :route_id,
      keyword_init: true
    )

    DEFAULT_MIDDLEWARE = %w[request_id].freeze

    module_function

    def match(table, method, path)
      verb = method.to_s.upcase
      table.each do |route|
        next unless route.verb == verb

        match = route_pattern(route.path).match(path.to_s)
        next unless match

        params = match.named_captures.transform_values { |value| URI.decode_www_form_component(value) }
        return [route, params]
      end
      nil
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
