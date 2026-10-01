# frozen_string_literal: true

require "json"
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

        raw = ORES_GS_HTTP.call(JSON.generate({
          method: method.to_s.upcase,
          path: path,
          query: query || {},
          body: body
        }))
        response = JSON.parse(raw.to_s)
        raise Error, response.fetch("error", "host HTTP bridge failed") unless response["ok"]

        body_text = response.fetch("body", "")
        parsed = body_text.empty? ? {} : JSON.parse(body_text)
        { status: Integer(response.fetch("status")), body: parsed }
      rescue JSON::ParserError => error
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
          req.body = JSON.generate(body) if body

          response = @http.request(req)
          parsed = response.body.to_s.empty? ? {} : JSON.parse(response.body)
          { status: response.code.to_i, body: parsed }
        rescue IOError, EOFError, SystemCallError
          reconnect!
          raise Error, "HTTP data connection reset; retry request through caller policy"
        rescue JSON::ParserError => error
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
          @http.keep_alive_timeout = Integer(ENV.fetch("DATA_API_KEEPALIVE_SECONDS", "30"))
          @http.start
        end
      end

      BASE_URL = ENV.fetch("DATA_API_URL", "http://127.0.0.1:8787/v1")
      TOKEN = ENV.fetch("DATA_API_TOKEN", "")
      POOL_SIZE = [Integer(ENV.fetch("DATA_API_HTTP_POOL_SIZE", "5")), 20].min
      POOL = ConnectionPool.new(size: POOL_SIZE, timeout: 2.0) do
        Session.new(base_url: BASE_URL, token: TOKEN)
      end
    end

    def self.request(method, path, body: nil, query: {})
      return GraalTransport.request(method, path, body: body, query: query) if GRAAL_RUNTIME

      POOL.with { |session| session.request(method, path, body: body, query: query) }
    rescue ConnectionPool::TimeoutError
      raise Error, "HTTP data connection pool exhausted"
    end
  end
end
