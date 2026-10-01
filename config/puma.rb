min_threads = Integer(ENV.fetch("RAILS_MIN_THREADS", "50"))
max_threads = Integer(ENV.fetch("RAILS_MAX_THREADS", "300"))
raise "RAILS_MIN_THREADS must be >= 1" if min_threads < 1
raise "RAILS_MAX_THREADS must be >= RAILS_MIN_THREADS" if max_threads < min_threads

threads min_threads, max_threads
port ENV.fetch("PORT", "3000")
environment ENV.fetch("RAILS_ENV", "development")
plugin :tmp_restart
