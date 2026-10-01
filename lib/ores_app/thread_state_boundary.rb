# frozen_string_literal: true

module OresApp
  module ThreadStateBoundary
    module_function

    def call
      thread = Thread.current
      fiber_state = thread.keys.to_h { |key| [key, thread[key]] }
      thread_state = thread.thread_variables.to_h { |key| [key, thread.thread_variable_get(key)] }

      yield
    ensure
      if thread
        (thread.keys - fiber_state.keys).each { |key| thread[key] = nil }
        fiber_state.each { |key, value| thread[key] = value }

        (thread.thread_variables - thread_state.keys).each do |key|
          thread.thread_variable_set(key, nil)
        end
        thread_state.each do |key, value|
          thread.thread_variable_set(key, value)
        end
      end
    end
  end
end
