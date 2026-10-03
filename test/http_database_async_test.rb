# frozen_string_literal: true

require "test_helper"

class HttpDatabaseAsyncTest < ActiveSupport::TestCase
  test "parallel requests overlap scheduler-aware operations on one Ruby thread" do
    skip "Fiber scheduler is unavailable on #{RUBY_ENGINE}" unless OresApp::HttpDatabase.async_fanout_enabled?

    events = []
    schedulers = []
    thread_ids = []

    request_stub = lambda do |_method, path, body: nil, query: {}|
      events << "#{path}:start"
      schedulers << Fiber.scheduler
      thread_ids << Thread.current.object_id
      sleep 0.01
      events << "#{path}:end"
      { status: 200, body: { "path" => path, "query" => query, "body" => body } }
    end

    result = OresApp::HttpDatabase.stub(:request, request_stub) do
      OresApp::HttpDatabase.parallel_requests(
        {
          first: { method: :get, path: "/first" },
          second: { method: :get, path: "/second" }
        },
        limit: 2
      )
    end

    first_end = events.index { |entry| entry.end_with?(":end") }
    starts_before_first_end = events.first(first_end).count { |entry| entry.end_with?(":start") }

    assert_equal 2, starts_before_first_end, events.inspect
    assert schedulers.all?, "every async operation should run with a Fiber scheduler"
    assert_equal 1, thread_ids.uniq.length, "fan-out should multiplex fibers on one Ruby thread"
    assert_equal "/first", result.fetch(:first).dig(:body, "path")
    assert_equal "/second", result.fetch(:second).dig(:body, "path")
  end

  test "fanout limit bounds active fibers" do
    skip "Fiber scheduler is unavailable on #{RUBY_ENGINE}" unless OresApp::HttpDatabase.async_fanout_enabled?

    active = 0
    peak = 0

    request_stub = lambda do |_method, path, body: nil, query: {}|
      active += 1
      peak = [peak, active].max
      sleep 0.01
      active -= 1
      { status: 200, body: { "path" => path, "query" => query, "body" => body } }
    end

    specs = 5.times.to_h do |index|
      [:"request_#{index}", { method: :get, path: "/#{index}" }]
    end

    OresApp::HttpDatabase.stub(:request, request_stub) do
      OresApp::HttpDatabase.parallel_requests(specs, limit: 2)
    end

    assert_equal 2, peak
  end

  test "scheduler capability matches the async fanout switch" do
    expected = defined?(Rails) && Fiber.respond_to?(:scheduler) && ENV.fetch("RAILS_ASYNC_IO", "1") != "0"
    assert_equal !!expected, !!OresApp::HttpDatabase.async_fanout_enabled?
  end

  test "Rails-free fallback can execute the same request set sequentially" do
    events = []

    request_stub = lambda do |_method, path, body: nil, query: {}|
      events << path
      { status: 200, body: { "path" => path, "query" => query, "body" => body } }
    end

    OresApp::HttpDatabase.stub(:request, request_stub) do
      result = OresApp::HttpDatabase.parallel_requests(
        {
          first: { method: :get, path: "/first" },
          second: { method: :get, path: "/second" }
        },
        async: false
      )

      assert_equal ["/first", "/second"], events
      assert_equal "/second", result.fetch(:second).dig(:body, "path")
    end
  end

  test "fanout rejects unbounded request sets" do
    specs = 17.times.to_h do |index|
      [:"request_#{index}", { method: :get, path: "/#{index}" }]
    end

    error = assert_raises(OresApp::HttpDatabase::Error) do
      OresApp::HttpDatabase.parallel_requests(specs)
    end

    assert_match(/exceeds 16 operations/, error.message)
  end
end
