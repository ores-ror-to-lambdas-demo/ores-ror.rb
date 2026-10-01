#!/usr/bin/env truffleruby
# frozen_string_literal: true

abort "Polyglot::InnerContext unavailable" unless defined?(Polyglot::InnerContext)

first_value = nil
second_initial = nil
second_value = nil

Polyglot::InnerContext.new(languages: ["ruby"], code_sharing: true) do |first|
  first_value = first.eval("ruby", '$ores_context_probe = "first"; $ores_context_probe').to_s

  Polyglot::InnerContext.new(languages: ["ruby"], code_sharing: true) do |second|
    second_initial = second.eval("ruby", 'defined?($ores_context_probe) ? $ores_context_probe : "unset"').to_s
    second_value = second.eval("ruby", '$ores_context_probe = "second"; $ores_context_probe').to_s
  end

  first_after_second = first.eval("ruby", '$ores_context_probe').to_s
  raise "first context state changed: #{first_after_second.inspect}" unless first_after_second == "first"
end

raise "first context setup failed" unless first_value == "first"
raise "state leaked into second context: #{second_initial.inspect}" unless second_initial == "unset"
raise "second context setup failed" unless second_value == "second"

puts "graal inner-context isolation smoke: ok"
