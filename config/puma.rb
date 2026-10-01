rails_env = ENV.fetch("RAILS_ENV", "development")
production = rails_env == "production"

default_min_threads = production ? 50 : 1
default_max_threads = production ? 300 : 5

min_threads = Integer(ENV.fetch("RAILS_MIN_THREADS", default_min_threads.to_s))
max_threads = Integer(ENV.fetch("RAILS_MAX_THREADS", default_max_threads.to_s))

raise "RAILS_MIN_THREADS must be >= 1" if min_threads < 1
raise "RAILS_MAX_THREADS must be >= RAILS_MIN_THREADS" if max_threads < min_threads
raise "RAILS_MAX_THREADS must be <= 300" if max_threads > 300

threads min_threads, max_threads
port ENV.fetch("PORT", "3000")
environment rails_env
plugin :tmp_restart
