#!/usr/bin/env truffleruby
# frozen_string_literal: true

require "json"
require "socket"
require_relative "worker_cluster"

module OresGraal
  class HttpServer
    STATUS_TEXT = {
      200 => "OK",
      201 => "Created",
      202 => "Accepted",
      204 => "No Content",
      400 => "Bad Request",
      404 => "Not Found",
      405 => "Method Not Allowed",
      500 => "Internal Server Error",
      502 => "Bad Gateway"
    }.freeze

    def initialize(host:, port:, cluster:)
      @host = host
      @port = Integer(port)
      @cluster = cluster
      @server = TCPServer.new(host, @port)
      @stopping = false
      @connection_threads = []
    end

    def run
      warn "ores-graal-cluster listening on #{@host}:#{@port} pid=#{Process.pid} contexts_per_handler=#{@cluster.contexts_per_handler}"
      until @stopping
        socket = @server.accept
        @connection_threads << Thread.new(socket) { |client| serve(client) }
        @connection_threads.reject! { |thread| !thread.alive? }
      end
    rescue IOError, Errno::EBADF
      raise unless @stopping
    ensure
      stop
    end

    def stop
      return if @stopping

      @stopping = true
      @server.close unless @server.closed?
      @cluster.close
      @connection_threads.each { |thread| thread.join(1) unless thread == Thread.current }
    end

    private

    def serve(socket)
      request = read_request(socket)
      return unless request

      response = if request["path"] == "/__ores/cluster"
                   cluster_status_response
                 else
                   @cluster.call(request)
                 end
      write_response(socket, response)
    rescue StandardError => error
      warn error.full_message(highlight: false, order: :top)
      write_response(socket, {
        "status" => 500,
        "headers" => { "content-type" => "application/json; charset=utf-8" },
        "body" => JSON.generate(error: error.message, error_class: error.class.name)
      })
    ensure
      socket.close unless socket.closed?
    end

    def read_request(socket)
      request_line = socket.gets
      return nil unless request_line

      method, target, _version = request_line.strip.split(" ", 3)
      raise ArgumentError, "invalid HTTP request line" unless method && target

      headers = {}
      while (line = socket.gets)
        line = line.chomp
        break if line.empty? || line == "\r"

        key, value = line.split(":", 2)
        raise ArgumentError, "invalid HTTP header" unless key && value
        headers[key.downcase] = value.strip
      end

      path, query_string = target.split("?", 2)
      content_length = Integer(headers.fetch("content-length", "0"), 10)
      raise ArgumentError, "request body too large" if content_length > 1_048_576
      body = content_length.positive? ? socket.read(content_length) : nil

      {
        "request_id" => headers["x-request-id"] || "graal-#{Process.pid}-#{Thread.current.object_id}",
        "method" => method,
        "path" => path,
        "query_string" => query_string,
        "content_type" => headers["content-type"],
        "headers" => headers,
        "body" => body
      }
    end

    def cluster_status_response
      {
        "status" => 200,
        "headers" => { "content-type" => "application/json; charset=utf-8", "x-ores-host-pid" => Process.pid.to_s },
        "body" => JSON.generate(@cluster.status)
      }
    end

    def write_response(socket, response)
      status = Integer(response.fetch("status"))
      body = response.fetch("body", "").to_s
      headers = response.fetch("headers", {}).transform_keys { |key| key.to_s.downcase }
      headers["content-length"] = body.bytesize.to_s
      headers["connection"] = "close"

      socket.write("HTTP/1.1 #{status} #{STATUS_TEXT.fetch(status, "Status")}\r\n")
      headers.each { |key, value| socket.write("#{key}: #{value}\r\n") }
      socket.write("\r\n")
      socket.write(body)
    rescue IOError, Errno::EPIPE
      nil
    end
  end
end

app_root = File.expand_path("..", __dir__)
manifest = File.join(app_root, "generated", "lambda", "manifest.json")
abort "generated Lambda/Graal runtime missing; run ORES_BUILD_TARGET=lambda bundle exec ruby bin/build-runtime" unless File.file?(manifest)

host = ENV.fetch("ORES_GRAAL_HOST", "127.0.0.1")
port = Integer(ENV.fetch("ORES_GRAAL_PORT", "3200"), 10)
contexts_per_handler = Integer(ENV.fetch("ORES_GRAAL_CONTEXTS_PER_HANDLER", "2"), 10)
cluster = OresGraal::WorkerCluster.new(app_root: app_root, contexts_per_handler: contexts_per_handler)
server = OresGraal::HttpServer.new(host: host, port: port, cluster: cluster)

Signal.trap("INT") { server.stop }
Signal.trap("TERM") { server.stop }
server.run
