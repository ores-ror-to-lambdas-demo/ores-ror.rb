# frozen_string_literal: true

require "test_helper"
require_relative "../lib/ores_app/url_codec"

class UrlCodecTest < ActiveSupport::TestCase
  test "decodes form components and repeated pairs without URI stdlib" do
    assert_equal "hello world/✓", OresApp::UrlCodec.decode_www_form_component("hello+world%2F%E2%9C%93")
    assert_equal(
      [["a", "1"], ["a", "two words"], ["empty", ""]],
      OresApp::UrlCodec.decode_www_form("a=1&a=two+words&empty=")
    )
  end

  test "rejects malformed escapes and invalid utf8" do
    assert_raises(ArgumentError) { OresApp::UrlCodec.decode_www_form_component("%") }
    assert_raises(ArgumentError) { OresApp::UrlCodec.decode_www_form_component("%GG") }
    assert_raises(ArgumentError) { OresApp::UrlCodec.decode_www_form_component("%FF") }
  end
end
