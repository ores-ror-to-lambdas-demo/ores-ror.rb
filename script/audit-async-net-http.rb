#!/usr/bin/env ruby
# frozen_string_literal: true

require "async"
require "net/http"
require "socket"
require "timeout"
require "uri"

server = TCPServer.new("127.0.0.1", 0)
port = server.addr[1]
accepted = Queue.new
release = Queue.new
workers = []

2.times do
  workers << Thread.new do
    socket = server.accept
    begin
      while (line = socket.gets)
        break if line == "\r\n"
      end
      accepted << true
      release.pop
      body = '{"ok":true}'
      socket.write(
        "HTTP/1.1 200 OK\r\n" \
        "Content-Type: application/json\r\n" \
        "Content-Length: #{body.bytesize}\r\n" \
        "Connection: close\r\n\r\n" \
        "#{body}"
      )
    ensure
      socket.close
    end
  end
end

coordinator = Thread.new do
  2.times { Timeout.timeout(2) { accepted.pop } }
  2.times { release << true }
end

client_thread_ids = []
scheduler_ids = []

responses = Timeout.timeout(3) do
  Sync do |parent|
    tasks = 2.times.map do |index|
      parent.async do
        client_thread_ids << Thread.current.object_id
        scheduler = Fiber.scheduler
        raise "missing Fiber scheduler" unless scheduler
        scheduler_ids << scheduler.object_id

        uri = URI("http://127.0.0.1:#{port}/#{index}")
        Net::HTTP.get_response(uri)
      end
    end

    tasks.map(&:wait)
  end
end

raise "unexpected status" unless responses.all? { |response| response.code == "200" }
raise "client fan-out used more than one Ruby thread" unless client_thread_ids.uniq.length == 1
raise "client fan-out used more than one scheduler" unless scheduler_ids.uniq.length == 1

puts "async Net::HTTP smoke passed: one Ruby thread, two fibers, two concurrent sockets"
ensure
  server&.close
  workers&.each { |thread| thread.join(1) }
  coordinator&.join(1)
