# frozen_string_literal: true

require_relative "../lib/ores_app/thread_state_boundary"

Thread.current[:baseline_fiber_local] = "baseline"
Thread.current.thread_variable_set(:baseline_thread_local, "baseline")

begin
  OresApp::ThreadStateBoundary.call do
    Thread.current[:baseline_fiber_local] = "mutated"
    Thread.current[:request_only_fiber_local] = "request"
    Thread.current.thread_variable_set(:baseline_thread_local, "mutated")
    Thread.current.thread_variable_set(:request_only_thread_local, "request")
    raise "exercise ensure cleanup"
  end
rescue RuntimeError => error
  raise unless error.message == "exercise ensure cleanup"
end

raise "fiber-local baseline not restored" unless Thread.current[:baseline_fiber_local] == "baseline"
raise "request fiber-local leaked" unless Thread.current[:request_only_fiber_local].nil?
raise "thread-local baseline not restored" unless Thread.current.thread_variable_get(:baseline_thread_local) == "baseline"
raise "request thread-local leaked" unless Thread.current.thread_variable_get(:request_only_thread_local).nil?

puts "thread-state boundary ok"
