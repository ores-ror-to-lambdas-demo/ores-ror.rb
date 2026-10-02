# frozen_string_literal: true

rails_env = ENV.fetch("RAILS_ENV", "development")

# Puma 8 has two useful concurrency dimensions:
#   * the ordinary reusable request-thread pool;
#   * additional threads that exist only while requests explicitly mark
#     themselves as I/O-bound.
#
# We keep a warm floor of 30, allow ordinary demand to grow the pool to 40,
# and reserve the final 10 slots for I/O-heavy Rails requests. This gives the
# process a hard default ceiling of 50 request-processing threads while letting
# blocked network work avoid crowding out CPU-capable request threads.
min_threads = Integer(ENV.fetch("RAILS_MIN_THREADS", "30"))
regular_max_threads = Integer(ENV.fetch("RAILS_REGULAR_MAX_THREADS", "40"))
total_max_threads = Integer(ENV.fetch("RAILS_MAX_THREADS", "50"))

raise "RAILS_MIN_THREADS must be >= 1" if min_threads < 1
raise "RAILS_REGULAR_MAX_THREADS must be >= RAILS_MIN_THREADS" if regular_max_threads < min_threads
raise "RAILS_MAX_THREADS must be >= RAILS_REGULAR_MAX_THREADS" if total_max_threads < regular_max_threads
raise "RAILS_MAX_THREADS must be <= 50" if total_max_threads > 50

io_thread_headroom = total_max_threads - regular_max_threads

threads min_threads, regular_max_threads
max_io_threads io_thread_headroom

# A fresh Fiber per request prevents fiber-local state from leaking between
# requests that reuse the same Puma worker thread.
fiber_per_request

port ENV.fetch("PORT", "3000")
environment rails_env

# Bound shutdown and drain accepted work rather than abandoning queued requests.
drain_on_shutdown
force_shutdown_after Integer(ENV.fetch("PUMA_FORCE_SHUTDOWN_AFTER", "30"))

# This demo is JSON/API oriented. Reject unexpectedly large request bodies at
# the server edge before Rails allocates/parses them.
http_content_length_limit Integer(ENV.fetch("MAX_REQUEST_BYTES", (1024 * 1024).to_s))

plugin :tmp_restart
