# frozen_string_literal: true

module OresApp
  module UrlCodec
    module_function

    def decode_www_form(value)
      value.to_s.split("&", -1).map do |field|
        key, separator, entry = field.partition("=")
        [decode_www_form_component(key), decode_www_form_component(separator.empty? ? "" : entry)]
      end
    end

    def decode_www_form_component(value)
      source = value.to_s.b
      output = String.new(capacity: source.bytesize, encoding: Encoding::BINARY)
      index = 0

      while index < source.bytesize
        byte = source.getbyte(index)
        case byte
        when 0x2B # +
          output << 0x20
        when 0x25 # %
          raise ArgumentError, "invalid percent escape" if index + 2 >= source.bytesize

          high = hex_value(source.getbyte(index + 1))
          low = hex_value(source.getbyte(index + 2))
          raise ArgumentError, "invalid percent escape" unless high && low

          output << ((high << 4) | low)
          index += 2
        else
          output << byte
        end
        index += 1
      end

      output.force_encoding(Encoding::UTF_8)
      raise ArgumentError, "URL component is not valid UTF-8" unless output.valid_encoding?

      output
    end

    def hex_value(byte)
      return byte - 0x30 if byte.between?(0x30, 0x39)
      return byte - 0x41 + 10 if byte.between?(0x41, 0x46)
      return byte - 0x61 + 10 if byte.between?(0x61, 0x66)

      nil
    end
    private_class_method :hex_value
  end
end
