# frozen_string_literal: true

module OresRails
  # Puma 8 can classify the thread executing a request as I/O-bound. Once that
  # happens, Puma may create an additional processor thread (up to
  # +max_io_threads+) while the marked request waits on external I/O.
  #
  # The current application surface is data-API-backed except for /healthz.
  # Keep the classification in one Rails-only middleware so Lambda/Graal
  # generated runtimes remain independent of Puma.
  class PumaIoBound
    CPU_ONLY_PATHS = ["/healthz"].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      marked = mark_io_bound(env)
      env["ores.puma.io_bound"] = marked
      @app.call(env)
    end

    private

    def mark_io_bound(env)
      return false if CPU_ONLY_PATHS.include?(env["PATH_INFO"].to_s)

      marker = env["puma.mark_as_io_bound"]
      return false unless marker.respond_to?(:call)

      marker.call
      true
    end
  end
end
