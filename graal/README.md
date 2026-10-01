# Graal runtime profile

This directory is intentionally runtime glue only. It is **not** a second Rails application.

- `bootstrap.rb` loads the repository's real `config/environment.rb` and invokes `Rails.application` through Rack.
- `graal-show.json` declares the Graal Show runtime/lifecycle contract.

Routes, controllers, services, models, middleware, validations, and business logic remain under the normal Rails tree and are shared by MRI/Puma and TruffleRuby/Graal execution.
