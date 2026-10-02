# frozen_string_literal: true

require "test_helper"
require_relative "../lib/ores_rails/puma_io_bound"

class PumaIoBoundTest < ActiveSupport::TestCase
  def app
    lambda do |env|
      [200, { "content-type" => "text/plain" }, [env["ores.puma.io_bound"] ? "io" : "regular"]]
    end
  end

  test "data-backed Rails routes mark Puma request threads as IO-bound" do
    marks = 0
    middleware = OresRails::PumaIoBound.new(app)

    status, _headers, body = middleware.call(
      "PATH_INFO" => "/users/demo",
      "puma.mark_as_io_bound" => -> { marks += 1 }
    )

    assert_equal 200, status
    assert_equal ["io"], body
    assert_equal 1, marks
  end

  test "health route preserves regular thread capacity" do
    marks = 0
    middleware = OresRails::PumaIoBound.new(app)

    _status, _headers, body = middleware.call(
      "PATH_INFO" => "/healthz",
      "puma.mark_as_io_bound" => -> { marks += 1 }
    )

    assert_equal ["regular"], body
    assert_equal 0, marks
  end

  test "middleware degrades safely when the Rack server is not Puma 8" do
    middleware = OresRails::PumaIoBound.new(app)

    _status, _headers, body = middleware.call("PATH_INFO" => "/users/demo")

    assert_equal ["regular"], body
  end
end
