# frozen_string_literal: true

require_relative "json_codec"
require "uri"

module OresApp
  class HttpDatabase
    class Error < StandardError; end

    GRAAL_RUNTIME = defined?(ORES_GRAAL_RUNTIME) && ORES_GRAAL_RUNTIME

    def self.runtime_name
      GRAAL_RUNTIME ? "truffleruby-graal" : RUBY_ENGINE
    end

    class GraalTransport
      def self.request(method, path, body:, query:)
        raise Error, "Graal host HTTP bridge is unavailable" unless defined?(ORES_GS_HTTP)

        raw = ORES_GS_HTTP.call(JsonCodec.generate({
          method: method.to_s.upcase,
          path: path,
          query: query || {},
          body: body
        }))
        response = JsonCodec.parse(raw.to_s)
        raise Error, response.fetch("error", "host HTTP bridge failed") unless response["ok"]

        body_text = response.fetch("body", "")
        parsed = body_text.empty? ? {} : JsonCodec.parse(body_text)
        { status: Integer(response.fetch("status")), body: parsed }
      rescue JsonCodec::ParseError => error
        raise Error, "data API returned invalid JSON: #{error.message}"
      end
    end

    unless GRAAL_RUNTIME
      require "connection_pool"
      require "net/http"

      class Session
        def initialize(base_url:, token:)
          @base = URI(base_url)
          raise Error, "DATA_API_URL must use http or https" unless %w[http https].include?(@base.scheme)
          @token = token
          connect!
        end

        def request(method, path, body:, query:)
          uri = @base.dup
          uri.path = [@base.path.sub(%r{/\z}, ""), path].join
          uri.query = URI.encode_www_form(query) unless query.nil? || query.empty?

          klass = {
            get: Net::HTTP::Get,
            post: Net::HTTP::Post,
            put: Net::HTTP::Put,
            patch: Net::HTTP::Patch,
            delete: Net::HTTP::Delete
          }.fetch(method.to_sym)

          req = klass.new(uri.request_uri)
          req["accept"] = "application/json"
          req["content-type"] = "application/json"
          req["authorization"] = "Bearer #{@token}" unless @token.empty?
          req.body = JsonCodec.generate(body) if body

          response = @http.request(req)
          body_text = response.body.to_s
          max_bytes = HttpDatabase.max_response_bytes
          raise Error, "data API response exceeded #{max_bytes} bytes" if body_text.bytesize > max_bytes

          parsed = body_text.empty? ? {} : JsonCodec.parse(body_text)
          { status: response.code.to_i, body: parsed }
        rescue IOError, EOFError, SystemCallError
          reconnect!
          raise Error, "HTTP data connection reset; retry request through caller policy"
        rescue JsonCodec::ParseError => error
          raise Error, "data API returned invalid JSON: #{error.message}"
        end

        def close
          @http.finish if @http&.started?
        rescue IOError
          nil
        end

        private

        def reconnect!
          close
          connect!
        end

        def connect!
          @http = Net::HTTP.new(@base.host, @base.port)
          @http.use_ssl = @base.scheme == "https"
          @http.open_timeout = Float(ENV.fetch("DATA_API_CONNECT_TIMEOUT", "2.0"))
          @http.read_timeout = Float(ENV.fetch("DATA_API_READ_TIMEOUT", "10.0"))
          @http.write_timeout = Float(ENV.fetch("DATA_API_WRITE_TIMEOUT", "10.0")) if @http.respond_to?(:write_timeout=)
          @http.keep_alive_timeout = Integer(ENV.fetch("DATA_API_KEEPALIVE_SECONDS", "30"))
          @http.max_retries = 0 if @http.respond_to?(:max_retries=)
          @http.start
        end
      end

      BASE_URL = ENV.fetch("DATA_API_URL", "http://127.0.0.1:8787/v1")
      TOKEN = ENV.fetch("DATA_API_TOKEN", "")

      # Rails can have up to 50 request-processing threads by default. Keep the
      # HTTP pool at the same ceiling so the data layer cannot become an
      # accidental 20-connection bottleneck. Rails-free runtimes retain a small
      # default because Lambda/Graal own concurrency differently.
      default_pool_size = defined?(Rails) ? Integer(ENV.fetch("RAILS_MAX_THREADS", "50")) : 5
      POOL_SIZE = Integer(ENV.fetch("DATA_API_HTTP_POOL_SIZE", default_pool_size.to_s))
      raise Error, "DATA_API_HTTP_POOL_SIZE must be between 1 and 50" unless POOL_SIZE.between?(1, 50)

      POOL_TIMEOUT = Float(ENV.fetch("DATA_API_POOL_TIMEOUT", "2.0"))
      MAX_RESPONSE_BYTES = Integer(ENV.fetch("DATA_API_MAX_RESPONSE_BYTES", (1024 * 1024).to_s))
      raise Error, "DATA_API_MAX_RESPONSE_BYTES must be >= 1" if MAX_RESPONSE_BYTES < 1

      POOL = ConnectionPool.new(size: POOL_SIZE, timeout: POOL_TIMEOUT) do
        Session.new(base_url: BASE_URL, token: TOKEN)
      end
    end

    def self.max_response_bytes
      return 1024 * 1024 if GRAAL_RUNTIME

      MAX_RESPONSE_BYTES
    end

    if GRAAL_RUNTIME
      def self.request(method, path, body: nil, query: {})
        GraalTransport.request(method, path, body: body, query: query)
      end
    else
      def self.request(method, path, body: nil, query: {})
        POOL.with { |session| session.request(method, path, body: body, query: query) }
      rescue ConnectionPool::TimeoutError
        raise Error, "HTTP data connection pool exhausted"
      end
    end
  end
end
