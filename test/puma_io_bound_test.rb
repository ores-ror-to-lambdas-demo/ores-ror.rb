# frozen_string_literal: true

require "test_helper"
require_relative "../lib/ores_rails/puma_io_bound"

class PumaIoBoundTest < ActiveSupport::TestCase
  FakeRequest = Struct.new(:env)

  test "controller IO classification marks the current Puma processor" do
    marks = 0
    request = FakeRequest.new({ "puma.mark_as_io_bound" => -> { marks += 1 } })

    assert_equal true, OresRails::PumaIoBound.mark!(request, enabled: true)
    assert_equal 1, marks
    assert_equal true, request.env["ores.puma.io_bound"]
  end

  test "CPU-bound controller policy does not consume IO headroom" do
    marks = 0
    request = FakeRequest.new("puma.mark_as_io_bound" => -> { marks += 1 })

    assert_equal false, OresRails::PumaIoBound.mark!(request, enabled: false)
    assert_equal 0, marks
    assert_nil request.env["ores.puma.io_bound"]
  end

  test "classification safely degrades outside Puma 8" do
    request = FakeRequest.new({})

    assert_equal false, OresRails::PumaIoBound.mark!(request, enabled: true)
  end

  test "health controller opts out while data controllers inherit IO policy" do
    assert_equal false, Healthz::Show::EndpointController.ores_puma_io_bound?
    assert_equal true, Users::Show::EndpointController.ores_puma_io_bound?
    assert_equal true, Products::Show::EndpointController.ores_puma_io_bound?
  end
end
