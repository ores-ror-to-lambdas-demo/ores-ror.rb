# frozen_string_literal: true

require "json"
require "net/http"
require "thread"
require "uri"
require_relative "../lib/ores_app/dispatcher"
require_relative "../lib/ores_app/routes"

module OresGraal
  STOP = Object.new.freeze

  module_function

  def ruby_const(value)
    value.to_s.split(/[^A-Za-z0-9]+/).reject(&:empty?).map { |part| part[0].upcase + part[1..].to_s }.join
  end

  def encode_wire(value)
    Marshal.dump(value).unpack1("H*")
  end

  def decode_wire(value)
    Marshal.load(["#{value}"].pack("H*"))
  end

  class HostHttpBridge
    def initialize(base_url: ENV.fetch("DATA_API_URL", "http://127.0.0.1:8787/v1"), token: ENV.fetch("DATA_API_TOKEN", ""))
      @base = URI(base_url)
      raise ArgumentError, "DATA_API_URL must use http or https" unless %w[http https].include?(@base.scheme)

      @token = token.to_s
    end

    def call(raw_wire)
      payload = OresGraal.decode_wire(raw_wire)
      uri = @base.dup
      uri.path = [@base.path.sub(%r{/\z}, ""), payload.fetch("path")].join
      query = payload["query"] || {}
      uri.query = URI.encode_www_form(query) unless query.empty?

      request_class = {
        "GET" => Net::HTTP::Get,
        "POST" => Net::HTTP::Post,
        "PUT" => Net::HTTP::Put,
        "PATCH" => Net::HTTP::Patch,
        "DELETE" => Net::HTTP::Delete
      }.fetch(payload.fetch("method").to_s.upcase)
      request = request_class.new(uri.request_uri)
      request["accept"] = "application/json"
      request["content-type"] = "application/json"
      request["authorization"] = "Bearer #{@token}" unless @token.empty?
      request.body = JSON.generate(payload["body"]) unless payload["body"].nil?

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = Float(ENV.fetch("DATA_API_CONNECT_TIMEOUT", "2.0"))
      http.read_timeout = Float(ENV.fetch("DATA_API_READ_TIMEOUT", "10.0"))
      response = http.start { |client| client.request(request) }
      body = response.body.to_s.empty? ? {} : JSON.parse(response.body)
      OresGraal.encode_wire("ok" => true, "status" => response.code.to_i, "body" => body)
    rescue StandardError => error
      OresGraal.encode_wire("ok" => false, "error" => "#{error.class}: #{error.message}")
    end
  end

  class Worker
    attr_reader :context_id, :pool_key

    def initialize(app_root:, route:, slot:, host_http_bridge:)
      @app_root = File.expand_path(app_root)
      @route = route
      @pool_key = OresApp::Routes.handler_relative_path(route)
      @context_id = "#{route.name}-#{slot}"
      @host_http_bridge = host_http_bridge.respond_to?(:call) ? host_http_bridge.method(:call) : host_http_bridge
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
            foreign_wire = invoker.call(OresGraal.encode_wire(request), @host_http_bridge)
            reply << [:ok, OresGraal.decode_wire(foreign_wire)]
          rescue StandardError => error
            reply << [:error, error]
          end
        end
      end
    rescue StandardError => error
      @ready << [:error, error] unless ready_sent
    end

    def bootstrap_source
      source_handler = File.join(@app_root, OresApp::Routes.handler_relative_path(@route))
      handler_const = OresGraal.ruby_const(@route.name)

      <<~RUBY
        # frozen_string_literal: true
        app_root = #{@app_root.dump}
        lib_root = File.join(app_root, "lib")
        $LOAD_PATH.unshift(lib_root) unless $LOAD_PATH.include?(lib_root)

        ORES_GRAAL_RUNTIME = true unless defined?(ORES_GRAAL_RUNTIME)
        ORES_GRAAL_WORKER = true unless defined?(ORES_GRAAL_WORKER)
        require File.join(app_root, "lib", "ores_app", "handlers")
        require #{source_handler.dump}

        module OresGraalWorkerEntrypoint
          EXPECTED_ROUTE = #{@route.name.inspect}
          CONTEXT_ID = #{@context_id.dump}
          POOL_KEY = #{@pool_key.dump}
          HANDLER = OresApp::RouteHandlers::#{handler_const}
          @invocations = 0

          module_function

          def decode_wire(value)
            Marshal.load(["\#{value}"].pack("H*"))
          end

          def encode_wire(value)
            Marshal.dump(value).unpack1("H*")
          end

          def worker_metadata
            {
              "model" => "graal-inner-context",
              "context_id" => CONTEXT_ID,
              "pool_key" => POOL_KEY,
              "handler" => EXPECTED_ROUTE.to_s,
              "invocations" => @invocations
            }
          end

          def call_wire(request_wire, host_http_bridge)
            $ores_gs_http = host_http_bridge
            request = decode_wire(request_wire)
            @invocations += 1
            response = HANDLER.call(request)
            encode_wire(
              "ok" => true,
              "response" => response,
              "worker" => worker_metadata
            )
          rescue StandardError => error
            encode_wire(
              "ok" => false,
              "error_class" => error.class.name,
              "message" => error.message.to_s,
              "worker" => worker_metadata
            )
          ensure
            $ores_gs_http = nil
          end
        end

        OresGraalWorkerEntrypoint.method(:call_wire)
      RUBY
    end
  end

  class WorkerPool
    attr_reader :pool_key

    def initialize(app_root:, route:, size:, host_http_bridge:)
      raise ArgumentError, "worker pool size must be >= 1" if size < 1

      @pool_key = OresApp::Routes.handler_relative_path(route)
      @workers = Array.new(size) do |index|
        Worker.new(
          app_root: app_root,
          route: route,
          slot: index,
          host_http_bridge: host_http_bridge
        )
      end
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

    def initialize(app_root:, contexts_per_handler: 2, host_http_bridge: HostHttpBridge.new)
      @app_root = File.expand_path(app_root)
      @contexts_per_handler = Integer(contexts_per_handler)
      raise ArgumentError, "contexts_per_handler must be between 1 and 32" unless (1..32).cover?(@contexts_per_handler)

      @host_http_bridge = host_http_bridge
      @pools = {}
      @pools_mutex = Mutex.new
    end

    def call(request)
      OresApp::Dispatcher.call(request, invoker: lambda do |route, normalized_request|
        payload = pool_for(route).call(normalized_request)
        worker = payload.fetch("worker")
        response = if payload.fetch("ok")
                     payload.fetch("response")
                   else
                     error_response(payload)
                   end
        headers = response[:headers] ||= {}
        headers["x-ores-worker-model"] = worker.fetch("model")
        headers["x-ores-worker-context"] = worker.fetch("context_id")
        headers["x-ores-worker-pool"] = worker.fetch("pool_key")
        headers["x-ores-worker-invocations"] = worker.fetch("invocations").to_s
        headers["x-ores-host-pid"] = Process.pid.to_s
        response
      end)
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
        "routing_boundary" => "outer-host",
        "worker_boundary" => "committed-handler",
        "context_wire" => "marshal-hex",
        "database_transport" => "outer-host-http-bridge",
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

    def error_response(payload)
      error_class = payload.fetch("error_class", "RuntimeError")
      status = case error_class
               when "OresApp::HttpDatabase::Error" then 502
               when "ArgumentError", "KeyError" then 400
               else 500
               end
      {
        status: status,
        headers: { "content-type" => "application/json; charset=utf-8" },
        body: { error: payload.fetch("message", "worker failed") }
      }
    end

    def pool_for(route)
      key = OresApp::Routes.handler_relative_path(route)
      @pools_mutex.synchronize do
        @pools[key] ||= WorkerPool.new(
          app_root: app_root,
          route: route,
          size: contexts_per_handler,
          host_http_bridge: @host_http_bridge
        )
      end
    end
  end
end
