#!/usr/bin/env truffleruby
# frozen_string_literal: true

abort "Polyglot::InnerContext unavailable" unless defined?(Polyglot::InnerContext)

class OuterBridgeProbe
  def call(value)
    "outer:#{value}"
  end
end

bridge = OuterBridgeProbe.new.method(:call)
result = nil

Polyglot::InnerContext.new(languages: ["ruby"], code_sharing: true) do |context|
  invoker = context.eval("ruby", <<~'RUBY')
    module InnerBridgeProbe
      module_function

      def call(callback, value)
        callback.call(value).to_s
      end
    end

    InnerBridgeProbe.method(:call)
  RUBY

  result = invoker.call(bridge, "ping").to_s
end

raise "outer Method bridge failed: #{result.inspect}" unless result == "outer:ping"
puts "graal inner-context host Method bridge smoke: ok"
