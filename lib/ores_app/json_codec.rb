# frozen_string_literal: true

module OresApp
  module JsonCodec
    class ParseError < StandardError; end

    module_function

    def generate(value)
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
        "[" + value.map { |entry| generate(entry) }.join(",") + "]"
      when Hash
        "{" + value.map { |key, entry| "#{encode_string(key.to_s)}:#{generate(entry)}" }.join(",") + "}"
      else
        return generate(value.to_h) if value.respond_to?(:to_h)
        raise ArgumentError, "unsupported JSON value: #{value.class}"
      end
    end

    def parse(value)
      Parser.new(value.to_s).parse
    end

    def encode_string(value)
      out = +'"'
      value.each_char do |char|
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
    private_class_method :encode_string

    class Parser
      def initialize(source)
        @source = source
        @index = 0
      end

      def parse
        skip_whitespace
        result = parse_value
        skip_whitespace
        error!("trailing content") unless eof?
        result
      end

      private

      def parse_value
        skip_whitespace
        error!("unexpected end of input") if eof?

        case current
        when '"' then parse_string
        when '{' then parse_object
        when '[' then parse_array
        when 't' then parse_literal("true", true)
        when 'f' then parse_literal("false", false)
        when 'n' then parse_literal("null", nil)
        else
          return parse_number if current == '-' || digit?(current)
          error!("unexpected token #{current.inspect}")
        end
      end

      def parse_object
        consume('{')
        object = {}
        skip_whitespace
        return consume('}') && object if current == '}'

        loop do
          skip_whitespace
          error!("object key must be a string") unless current == '"'
          key = parse_string
          skip_whitespace
          consume(':')
          object[key] = parse_value
          skip_whitespace
          break if current == '}' && consume('}')
          consume(',')
        end
        object
      end

      def parse_array
        consume('[')
        array = []
        skip_whitespace
        return consume(']') && array if current == ']'

        loop do
          array << parse_value
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
        token.match?(/[.eE]/) ? Float(token) : Integer(token, 10)
      rescue ArgumentError
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
        raise ParseError, "#{message} at byte #{@index}"
      end
    end
  end
end
