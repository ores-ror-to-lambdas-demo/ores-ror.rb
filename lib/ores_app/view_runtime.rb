# frozen_string_literal: true

require "erb"

module OresApp
  module ViewRuntime
    module_function

    def add(templates)
      @templates ||= {}
      @templates.merge!(templates)
      self
    end

    def render(template, format, locals)
      @templates ||= {}
      key = "#{template}.#{format}.erb"
      source = @templates.fetch(key) { raise KeyError, "missing embedded view #{key}" }
      scope = Object.new
      locals.each do |name, value|
        scope.define_singleton_method(name) { value }
      end
      ERB.new(source).result(scope.instance_eval { binding })
    end
  end
end
