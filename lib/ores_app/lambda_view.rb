# frozen_string_literal: true

require "erb"
require "json"

module OresApp
  module LambdaView
    class Context
      def initialize(payload)
        @payload = payload
      end

      def raw(value)
        value.to_s
      end

      def get_binding
        binding
      end
    end

    module_function

    def render(view_name, template_source, result)
      body = ERB.new(template_source, trim_mode: "-").result(Context.new(result.fetch(:body)).get_binding)
      {
        status: Integer(result.fetch(:status)),
        headers: result.fetch(:headers, {}).merge("x-ores-view" => view_name),
        body: body
      }
    end
  end
end
