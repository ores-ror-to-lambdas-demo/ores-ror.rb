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
    mark_html_safe(JSON.generate(to_h))
  end

  def html_json_view
    escaped = JSON.generate(to_h)
      .gsub("&", "&amp;")
      .gsub("<", "&lt;")
      .gsub(">", "&gt;")
      .gsub('"', "&quot;")
      .gsub("'", "&#39;")
    mark_html_safe(escaped)
  end

  def view_title
    self.class.name
  end

  private

  def mark_html_safe(value)
    value.respond_to?(:html_safe) ? value.html_safe : value
  end

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
