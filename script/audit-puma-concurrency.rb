#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "puma"
require "puma/configuration"

path = File.expand_path("../config/puma.rb", __dir__)
config = Puma::Configuration.new(config_file: path)
config.load
config.clamp
options = config.options

expected = {
  min_threads: Integer(ENV.fetch("RAILS_MIN_THREADS", "30")),
  max_threads: Integer(ENV.fetch("RAILS_REGULAR_MAX_THREADS", "40")),
  max_io_threads: Integer(ENV.fetch("RAILS_MAX_THREADS", "50")) - Integer(ENV.fetch("RAILS_REGULAR_MAX_THREADS", "40")),
  fiber_per_request: true
}

actual = expected.keys.to_h { |key| [key, options[key]] }

expected.each do |key, value|
  raise "#{key}: expected #{value.inspect}, got #{actual[key].inspect}" unless actual[key] == value
end

total_ceiling = actual.fetch(:max_threads) + actual.fetch(:max_io_threads)
raise "total request thread ceiling must not exceed 50" if total_ceiling > 50
raise "default total request thread ceiling must be 50" if ENV["RAILS_MAX_THREADS"].nil? && total_ceiling != 50

puts JSON.pretty_generate({
  puma_version: Puma::Const::PUMA_VERSION,
  concurrency: actual,
  total_request_thread_ceiling: total_ceiling,
  model: "30 warm -> 40 regular demand -> 50 with IO headroom"
})
