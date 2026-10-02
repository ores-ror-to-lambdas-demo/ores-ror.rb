# frozen_string_literal: true

module OresApp
  module JsonCodec
    class ParseError < StandardError; end

    MAX_DOCUMENT_BYTES = 1024 * 1024
    MAX_NESTING = 64

    module_function

    def generate(value)
      encoded = encode_value(value, 0, {})
      raise ArgumentError, "JSON document exceeds #{MAX_DOCUMENT_BYTES} bytes" if encoded.bytesize > MAX_DOCUMENT_BYTES

      encoded
    end

    def parse(value)
      source = normalize_input(value)
      raise ParseError, "JSON document exceeds #{MAX_DOCUMENT_BYTES} bytes" if source.bytesize > MAX_DOCUMENT_BYTES

      Parser.new(source).parse
    end

    def encode_value(value, depth, seen)
      raise ArgumentError, "JSON nesting exceeds #{MAX_NESTING}" if depth > MAX_NESTING

      case value
      when nil
        "null"
      when true
        "true"
      when false
        "false"
      when String
        encode_string(value)
      when Symbol
        encode_string(value.to_s)
      when Integer
        value.to_s
      when Float
        raise ArgumentError, "non-finite JSON number" unless value.finite?
        value.to_s
      when Array
        with_container(value, seen) do
          "[" + value.map { |entry| encode_value(entry, depth + 1, seen) }.join(",") + "]"
        end
      when Hash
        with_container(value, seen) do
          keys = {}
          body = value.map do |key, entry|
            normalized_key = normalize_string(key.to_s)
            raise ArgumentError, "duplicate JSON object key after string conversion: #{normalized_key.inspect}" if keys.key?(normalized_key)

            keys[normalized_key] = true
            "#{encode_string(normalized_key)}:#{encode_value(entry, depth + 1, seen)}"
          end
          "{" + body.join(",") + "}"
        end
      else
        return encode_value(value.to_h, depth + 1, seen) if value.respond_to?(:to_h)

        raise ArgumentError, "unsupported JSON value: #{value.class}"
      end
    end

    def with_container(value, seen)
      identity = value.__id__
      raise ArgumentError, "cyclic JSON value" if seen.key?(identity)

      seen[identity] = true
      yield
    ensure
      seen.delete(identity) if defined?(identity)
    end

    def normalize_input(value)
      source = value.to_s.dup
      unless source.encoding.ascii_compatible?
        source = source.encode(Encoding::UTF_8)
      end
      source.force_encoding(Encoding::UTF_8)
      raise ParseError, "JSON input is not valid UTF-8" unless source.valid_encoding?

      source
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      raise ParseError, "JSON input is not valid UTF-8"
    end

    def normalize_string(value)
      string = value.to_s.dup
      unless string.encoding.ascii_compatible?
        string = string.encode(Encoding::UTF_8)
      end
      string.force_encoding(Encoding::UTF_8)
      raise ArgumentError, "JSON string is not valid UTF-8" unless string.valid_encoding?

      string
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      raise ArgumentError, "JSON string is not valid UTF-8"
    end

    def encode_string(value)
      string = normalize_string(value)
      out = +'"'
      string.each_char do |char|
        out << case char
               when '"' then '\\"'
               when "\\" then "\\\\"
               when "\b" then "\\b"
               when "\f" then "\\f"
               when "\n" then "\\n"
               when "\r" then "\\r"
               when "\t" then "\\t"
               else
                 codepoint = char.ord
                 codepoint < 0x20 ? format("\\u%04x", codepoint) : char
               end
      end
      out << '"'
    end

    private_class_method :encode_value, :with_container, :normalize_input, :normalize_string, :encode_string

    class Parser
      def initialize(source)
        @source = source
        @index = 0
      end

      def parse
        skip_whitespace
        result = parse_value(0)
        skip_whitespace
        error!("trailing content") unless eof?
        result
      end

      private

      def parse_value(depth)
        error!("JSON nesting exceeds #{MAX_NESTING}") if depth > MAX_NESTING

        skip_whitespace
        error!("unexpected end of input") if eof?

        case current
        when '"' then parse_string
        when '{' then parse_object(depth)
        when '[' then parse_array(depth)
        when 't' then parse_literal("true", true)
        when 'f' then parse_literal("false", false)
        when 'n' then parse_literal("null", nil)
        else
          return parse_number if current == '-' || digit?(current)
          error!("unexpected token #{current.inspect}")
        end
      end

      def parse_object(depth)
        consume('{')
        object = {}
        skip_whitespace
        return consume('}') && object if current == '}'

        loop do
          skip_whitespace
          error!("object key must be a string") unless current == '"'
          key = parse_string
          error!("duplicate object key #{key.inspect}") if object.key?(key)

          skip_whitespace
          consume(':')
          object[key] = parse_value(depth + 1)
          skip_whitespace
          break if current == '}' && consume('}')
          consume(',')
        end
        object
      end

      def parse_array(depth)
        consume('[')
        array = []
        skip_whitespace
        return consume(']') && array if current == ']'

        loop do
          array << parse_value(depth + 1)
          skip_whitespace
          break if current == ']' && consume(']')
          consume(',')
        end
        array
      end

      def parse_string
        consume('"')
        out = +""

        until eof?
          char = take
          return out if char == '"'
          error!("unescaped control character") if char.ord < 0x20

          if char == "\\"
            error!("unterminated escape") if eof?
            escaped = take
            case escaped
            when '"', "\\", '/'
              out << escaped
            when 'b' then out << "\b"
            when 'f' then out << "\f"
            when 'n' then out << "\n"
            when 'r' then out << "\r"
            when 't' then out << "\t"
            when 'u'
              codepoint = parse_hex4
              if codepoint.between?(0xD800, 0xDBFF)
                consume('\\')
                consume('u')
                low = parse_hex4
                error!("invalid unicode surrogate pair") unless low.between?(0xDC00, 0xDFFF)
                codepoint = 0x10000 + ((codepoint - 0xD800) << 10) + (low - 0xDC00)
              elsif codepoint.between?(0xDC00, 0xDFFF)
                error!("unexpected low unicode surrogate")
              end
              out << [codepoint].pack("U")
            else
              error!("invalid escape \\#{escaped}")
            end
          else
            out << char
          end
        end

        error!("unterminated string")
      end

      def parse_hex4
        token = @source[@index, 4]
        error!("invalid unicode escape") unless token&.length == 4 && token.match?(/\A[0-9A-Fa-f]{4}\z/)
        @index += 4
        token.to_i(16)
      end

      def parse_number
        match = @source.match(/\G-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/, @index)
        error!("invalid number") unless match

        token = match[0]
        @index = match.end(0)
        number = token.match?(/[.eE]/) ? Float(token) : Integer(token, 10)
        error!("non-finite JSON number") if number.is_a?(Float) && !number.finite?
        number
      rescue ArgumentError, FloatDomainError
        error!("invalid number")
      end

      def parse_literal(token, value)
        error!("invalid literal") unless @source[@index, token.length] == token
        @index += token.length
        value
      end

      def skip_whitespace
        @index += 1 while !eof? && current.match?(/[ \t\r\n]/)
      end

      def consume(expected)
        error!("expected #{expected.inspect}") unless current == expected
        @index += 1
        true
      end

      def take
        char = current
        @index += 1
        char
      end

      def current
        @source[@index]
      end

      def eof?
        @index >= @source.length
      end

      def digit?(char)
        char && char >= '0' && char <= '9'
      end

      def error!(message)
        raise ParseError, "#{message} at offset #{@index}"
      end
    end
  end
end
