# frozen_string_literal: true

require "test_helper"
require_relative "../lib/ores_app/json_codec"

class JsonCodecTest < ActiveSupport::TestCase
  test "round trips nested JSON without stdlib JSON" do
    value = {
      "string" => "hello \"world\" \\ line\n✓",
      "integer" => 42,
      "float" => 1.25,
      "true" => true,
      "false" => false,
      "nil" => nil,
      "array" => [1, "two", { "three" => 3 }]
    }

    encoded = OresApp::JsonCodec.generate(value)
    assert_equal value, OresApp::JsonCodec.parse(encoded)
  end

  test "parses unicode surrogate pairs and exponents" do
    value = OresApp::JsonCodec.parse(%q({"emoji":"\uD83D\uDE80","n":-1.25e2}))
    assert_equal "🚀", value.fetch("emoji")
    assert_equal(-125.0, value.fetch("n"))
  end

  test "rejects trailing content and invalid JSON" do
    assert_raises(OresApp::JsonCodec::ParseError) { OresApp::JsonCodec.parse("{} nope") }
    assert_raises(OresApp::JsonCodec::ParseError) { OresApp::JsonCodec.parse('{"x":}') }
  end

  test "rejects non finite numbers when generating" do
    assert_raises(ArgumentError) { OresApp::JsonCodec.generate(Float::INFINITY) }
    assert_raises(ArgumentError) { OresApp::JsonCodec.generate(Float::NAN) }
  end
end
