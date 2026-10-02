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

  test "rejects trailing content invalid json duplicate keys and non finite parsed numbers" do
    assert_raises(OresApp::JsonCodec::ParseError) { OresApp::JsonCodec.parse("{} nope") }
    assert_raises(OresApp::JsonCodec::ParseError) { OresApp::JsonCodec.parse('{"x":}') }
    assert_raises(OresApp::JsonCodec::ParseError) { OresApp::JsonCodec.parse('{"x":1,"x":2}') }
    assert_raises(OresApp::JsonCodec::ParseError) { OresApp::JsonCodec.parse("1e9999") }
  end

  test "rejects excessive nesting and oversized input" do
    too_deep = ("[" * (OresApp::JsonCodec::MAX_NESTING + 2)) +
      ("0") +
      ("]" * (OresApp::JsonCodec::MAX_NESTING + 2))
    assert_raises(OresApp::JsonCodec::ParseError) { OresApp::JsonCodec.parse(too_deep) }

    oversized = '"' + ("a" * OresApp::JsonCodec::MAX_DOCUMENT_BYTES) + '"'
    assert_raises(OresApp::JsonCodec::ParseError) { OresApp::JsonCodec.parse(oversized) }
  end

  test "rejects cycles duplicate generated keys invalid utf8 and non finite numbers" do
    cycle = []
    cycle << cycle
    assert_raises(ArgumentError) { OresApp::JsonCodec.generate(cycle) }
    assert_raises(ArgumentError) { OresApp::JsonCodec.generate({ "x" => 1, x: 2 }) }
    assert_raises(ArgumentError) { OresApp::JsonCodec.generate(Float::INFINITY) }
    assert_raises(ArgumentError) { OresApp::JsonCodec.generate(Float::NAN) }

    invalid = "\xFF".b
    assert_raises(ArgumentError) { OresApp::JsonCodec.generate(invalid) }
    assert_raises(OresApp::JsonCodec::ParseError) { OresApp::JsonCodec.parse(invalid) }
  end
end
