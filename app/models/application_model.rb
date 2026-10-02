# frozen_string_literal: true

class ApplicationModel
  attr_reader :attributes

  def initialize(attributes = {})
    @attributes = normalize(attributes).freeze
  end

  def [](key)
    attributes[key.to_s]
  end

  def to_h
    attributes
  end

  def json_view
    json = JSON.generate(to_h)
    json.respond_to?(:html_safe) ? json.html_safe : json
  end

  private

  def normalize(value)
    case value
    when Hash
      value.each_with_object({}) { |(key, entry), out| out[key.to_s] = normalize(entry) }
    when Array
      value.map { |entry| normalize(entry) }
    else
      value
    end
  end
end
