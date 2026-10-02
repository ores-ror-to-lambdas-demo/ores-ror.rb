# frozen_string_literal: true

module OresApp
  module ViewRuntime
    module_function

    def add(renderers)
      @renderers ||= {}
      renderers.each do |name, renderer|
        raise ArgumentError, "embedded view renderer must be callable: #{name}" unless renderer.respond_to?(:call)
        @renderers[name] = renderer
      end
      self
    end

    def render(template, format, locals)
      @renderers ||= {}
      key = "#{template}.#{format}.erb"
      renderer = @renderers.fetch(key) { raise KeyError, "missing embedded view #{key}" }
      renderer.call(locals)
    end
  end
end
