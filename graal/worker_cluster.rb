# frozen_string_literal: true

require "json"
require "thread"
require_relative "../lib/ores_app/routes"

module OresGraal
  STOP = Object.new.freeze

  module_function

  def ruby_const(value)
    value.to_s.split(/[^A-Za-z0-9]+/).reject(&:empty?).map { |part| part[0].upcase + part[1..].to_s }.join
  end

  class Worker
    attr_reader :context_id, :pool_key

    def initialize(app_root:, route:, slot:)
      @app_root = File.expand_path(app_root)
      @route = route
      @pool_key = OresApp::Routes.handler_relative_path(route)
      @context_id = "#{route.name}-#{slot}"
      @jobs = Queue.new
      @ready = Queue.new
      @thread = Thread.new { run }

      status, payload = @ready.pop
      raise payload if status == :error
    end

    def call(request)
      reply = Queue.new
      @jobs << [request, reply]
      status, payload = reply.pop
      raise payload if status == :error

      payload
    end

    def close
      @jobs << STOP
      @thread.join(5)
    end

    private

    def run
      unless defined?(Polyglot::InnerContext)
        raise "Polyglot::InnerContext is unavailable; run this host with TruffleRuby/GraalVM (prefer --jvm)"
      end

      ready_sent = false
      Polyglot::InnerContext.new(
        languages: ["ruby"],
        inherit_all_access: true,
        code_sharing: true
      ) do |context|
        invoker = context.eval("ruby", bootstrap_source)
        @ready << [:ok, nil]
        ready_sent = true

        loop do
          job = @jobs.pop
          break if job.equal?(STOP)

          request, reply = job
          begin
            raw = invoker.call(JSON.generate(request)).to_s
            reply << [:ok, JSON.parse(raw)]
          rescue StandardError => error
            reply << [:error, error]
          end
        end
      end
    rescue StandardError => error
      @ready << [:error, error] unless ready_sent
    end

    def bootstrap_source
      generated_handler = File.join(
        @app_root,
        "generated",
        "lambda",
        "routes",
        OresApp::Routes.handler_relative_path(@route).delete_prefix("routes/")
      )
      generated_module = OresGraal.ruby_const(@route.name)

      <<~RUBY
        # frozen_string_literal: true
        require "json"
        begin
          require "rubygems"
          require "bundler/setup"
        rescue LoadError
          # bundle exec already provides the admitted load path in normal operation.
        end

        app_root = #{@app_root.dump}
        lib_root = File.join(app_root, "lib")
        $LOAD_PATH.unshift(lib_root) unless $LOAD_PATH.include?(lib_root)

        ORES_GRAAL_WORKER = true unless defined?(ORES_GRAAL_WORKER)
        require File.join(app_root, "lib", "ores_app", "dispatcher")
        require #{generated_handler.dump}

        module OresGraalWorkerEntrypoint
          EXPECTED_ROUTE = #{@route.name.inspect}
          CONTEXT_ID = #{@context_id.dump}
          POOL_KEY = #{@pool_key.dump}
          HANDLER = OresGenerated::Routes::#{generated_module}
          @invocations = 0

          module_function

          def call_json(request_json)
            request = JSON.parse(request_json)
            response = OresApp::Dispatcher.call(request, invoker: lambda do |route, normalized_request|
              unless route.name == EXPECTED_ROUTE
                raise ArgumentError, "context \#{CONTEXT_ID} belongs to \#{EXPECTED_ROUTE.inspect}, got \#{route.name.inspect}"
              end

              HANDLER.call(normalized_request)
            end)

            @invocations += 1
            JSON.generate(
              "response" => response,
              "worker" => {
                "model" => "graal-inner-context",
                "context_id" => CONTEXT_ID,
                "pool_key" => POOL_KEY,
                "handler" => EXPECTED_ROUTE.to_s,
                "invocations" => @invocations
              }
            )
          end
        end

        OresGraalWorkerEntrypoint.method(:call_json)
      RUBY
    end
  end

  class WorkerPool
    attr_reader :pool_key

    def initialize(app_root:, route:, size:)
      raise ArgumentError, "worker pool size must be >= 1" if size < 1

      @pool_key = OresApp::Routes.handler_relative_path(route)
      @workers = Array.new(size) { |index| Worker.new(app_root: app_root, route: route, slot: index) }
      @available = Queue.new
      @workers.each { |worker| @available << worker }
    end

    def call(request)
      worker = @available.pop
      begin
        worker.call(request)
      ensure
        @available << worker
      end
    end

    def status
      {
        "pool_key" => pool_key,
        "contexts" => @workers.map(&:context_id),
        "size" => @workers.length
      }
    end

    def close
      @workers.each(&:close)
    end
  end

  class WorkerCluster
    attr_reader :app_root, :contexts_per_handler

    def initialize(app_root:, contexts_per_handler: 2)
      @app_root = File.expand_path(app_root)
      @contexts_per_handler = Integer(contexts_per_handler)
      raise ArgumentError, "contexts_per_handler must be between 1 and 32" unless (1..32).cover?(@contexts_per_handler)

      @pools = {}
      @pools_mutex = Mutex.new
    end

    def call(request)
      method = request.fetch("method", "GET").to_s.upcase
      path = request.fetch("path", "/").to_s
      match = OresApp::Routes.match(method, path)
      return not_found unless match

      route, = match
      payload = pool_for(route).call(request)
      response = payload.fetch("response")
      worker = payload.fetch("worker")
      headers = response["headers"] ||= {}
      headers["x-ores-worker-model"] = worker.fetch("model")
      headers["x-ores-worker-context"] = worker.fetch("context_id")
      headers["x-ores-worker-pool"] = worker.fetch("pool_key")
      headers["x-ores-worker-invocations"] = worker.fetch("invocations").to_s
      headers["x-ores-host-pid"] = Process.pid.to_s
      response
    end

    def status
      pools = @pools_mutex.synchronize { @pools.values.map(&:status) }
      {
        "worker_model" => "graal-inner-context",
        "worker_is_os_process" => false,
        "worker_is_dedicated_process" => false,
        "host_pid" => Process.pid,
        "contexts_per_handler" => contexts_per_handler,
        "pool_key" => "handler-path",
        "cross_handler_context_reuse" => false,
        "host_thread_strategy" => "one-host-thread-per-live-inner-context",
        "configured_handlers" => OresApp::Routes::TABLE.length,
        "initialized_pools" => pools
      }
    end

    def close
      pools = @pools_mutex.synchronize do
        current = @pools.values
        @pools = {}
        current
      end
      pools.each(&:close)
    end

    private

    def pool_for(route)
      key = OresApp::Routes.handler_relative_path(route)
      @pools_mutex.synchronize do
        @pools[key] ||= WorkerPool.new(
          app_root: app_root,
          route: route,
          size: contexts_per_handler
        )
      end
    end

    def not_found
      {
        "status" => 404,
        "headers" => { "content-type" => "application/json; charset=utf-8", "x-ores-host-pid" => Process.pid.to_s },
        "body" => JSON.generate(error: "route not found")
      }
    end
  end
end
