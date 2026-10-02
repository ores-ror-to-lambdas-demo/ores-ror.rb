#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"

PATTERNS = {
  "fiber_local_thread_current" => /Thread\.current\s*\[/,
  "true_thread_variable" => /(?:Thread\.current\.)?thread_variable_(?:get|set)|thread_variables|thread_variable\?/,
  "thread_creation" => /Thread\.(?:new|start|fork)\b/,
  "fiber_creation" => /Fiber\.(?:new|schedule)\b/,
  "rails_execution_state" => /ActiveSupport::(?:CurrentAttributes|IsolatedExecutionState)/,
  "request_store" => /\bRequestStore\b/,
  "concurrent_thread_local" => /Concurrent::ThreadLocalVar/
}.freeze

DEFAULT_ROOTS = %w[app lib routes config].freeze
MAX_EXAMPLES_PER_CATEGORY = Integer(ENV.fetch("ORES_THREAD_STATE_MAX_EXAMPLES", "25"))

roots = ARGV.empty? ? DEFAULT_ROOTS : ARGV
findings = Hash.new { |hash, key| hash[key] = [] }
scanned_files = 0

roots.each do |root|
  path = Pathname(root)
  next unless path.exist?

  files = path.file? ? [path] : path.glob("**/*.rb")
  files.each do |file|
    next unless file.file?

    scanned_files += 1
    begin
      file.each_line.with_index(1) do |line, line_number|
        PATTERNS.each do |category, pattern|
          next unless line.match?(pattern)

          findings[category] << {
            "path" => file.to_s,
            "line" => line_number,
            "source" => line.strip[0, 240]
          }
        end
      end
    rescue ArgumentError, Encoding::InvalidByteSequenceError
      warn "skipping non-text Ruby source: #{file}"
    end
  end
end

summary = PATTERNS.keys.to_h { |category| [category, findings[category].length] }
puts JSON.pretty_generate(
  "schema" => "ores-ruby-execution-state-audit/v1",
  "scanned_files" => scanned_files,
  "roots" => roots,
  "counts" => summary,
  "examples" => PATTERNS.keys.to_h do |category|
    [category, findings[category].first(MAX_EXAMPLES_PER_CATEGORY)]
  end
)

fail_on = ENV.fetch("ORES_THREAD_STATE_FAIL_ON", "")
  .split(",")
  .map(&:strip)
  .reject(&:empty?)
unknown = fail_on - PATTERNS.keys
abort "unknown ORES_THREAD_STATE_FAIL_ON categories: #{unknown.join(", ")}" unless unknown.empty?

violations = fail_on.select { |category| findings[category].any? }
exit(1) unless violations.empty?
