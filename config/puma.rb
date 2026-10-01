max_threads = Integer(ENV.fetch("RAILS_MAX_THREADS", "5"))
threads 1, [max_threads, 5].min
port ENV.fetch("PORT", "3000")
environment ENV.fetch("RAILS_ENV", "development")
plugin :tmp_restart
