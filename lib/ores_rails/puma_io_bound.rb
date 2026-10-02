# frozen_string_literal: true

module OresRails
  # Puma 8 can classify the currently executing request as I/O-bound. Puma may
  # then replace that blocked capacity with an additional processor thread up
  # to +max_io_threads+.
  #
  # This helper is called from the Rails controller boundary, after routing has
  # selected a real endpoint. That avoids classifying 404s, assets, or other
  # Rack traffic as data-I/O work.
  module PumaIoBound
    module_function

    def mark!(request, enabled: true)
      return false unless enabled

      env = request.respond_to?(:env) ? request.env : request
      marker = env["puma.mark_as_io_bound"]
      return false unless marker.respond_to?(:call)

      marker.call
      env["ores.puma.io_bound"] = true
      true
    end
  end
end
