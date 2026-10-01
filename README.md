# ores-ror.rb

One normal Rails application that can also be packaged as Rails-free per-endpoint Lambda/Graal handlers without maintaining a second application tree.

## Rails remains the source application

The repository keeps the normal Rails shape:

```text
app/
  controllers/
  models/
  views/
  jobs/
  mailers/
  helpers/
  services/
config/
  routes.rb
  application.rb
  environment.rb
  environments/
  initializers/
db/
lib/
public/
test/
config.ru
Gemfile
Rakefile
```

`config/routes.rb` remains the Rails router. `lib/ores_app/routes.rb` is the Rails-independent metadata mirror used by build tooling so Lambda/Graal packaging never has to boot Rails.

## One endpoint folder, one tracked controller, one generated handler

Every endpoint gets its own controller directory under `app/controllers`. The Rails controller is tracked. `handler.rb` is generated beside it and is ignored by Git.

Examples:

```text
app/controllers/
├── users/
│   └── show/
│       ├── users_controller.rb   # tracked Rails source
│       └── handler.rb            # generated, ignored
├── checkout_sessions/
│   └── create/
│       ├── checkout_sessions_controller.rb
│       └── handler.rb
├── orders/
│   ├── show/
│   │   ├── orders_controller.rb
│   │   └── handler.rb
│   └── cancel/
│       ├── orders_controller.rb
│       └── handler.rb
└── healthz/
    └── show/
        ├── healthz_controller.rb
        └── handler.rb
```

The generated file is packaging/runtime glue, not authored application code. A clean checkout contains the Rails controllers but no endpoint `handler.rb` files. `.gitignore` excludes `app/controllers/**/handler.rb`, and CI verifies none are tracked.

## Build targets

```sh
# Ordinary Rails/Puma. No generated endpoint handlers are required.
ORES_BUILD_TARGET=rails bundle exec rails server

# Generate sibling endpoint handlers + AWS Lambda entrypoint/manifest.
ORES_BUILD_TARGET=lambda ruby bin/build-runtime

# Generate sibling endpoint handlers + one flattened TruffleRuby/Graal bundle.
ORES_BUILD_TARGET=graal ruby bin/build-runtime
```

Rails mode preserves normal Rails routing, controllers, sessions, ActiveRecord, middleware, views, Action Cable, gems, and the rest of the application runtime. Lambda/Graal mode does not boot `config/environment.rb` or `Rails.application`; generated endpoint handlers enter the Rails-independent application core.

## Lambda topology

Each route-level Lambda unit is the generated `handler.rb` beside its Rails controller. The manifest records both locations:

```json
{
  "source_controller": "app/controllers/orders/cancel/orders_controller.rb",
  "generated_handler": "app/controllers/orders/cancel/handler.rb"
}
```

Higher-level grouped handlers are also generated under `generated/lambda/groups/`. A grouped handler may switch among a family such as all order endpoints, while the route-level generated handlers remain colocated with the Rails controllers.

```sh
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=route ruby bin/build-runtime
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=group ruby bin/build-runtime
```

## Graal/TruffleRuby isolate model

The Graal build flattens the Rails-independent core plus the generated endpoint handlers into `generated/graal/handler.rb`. Runtime guest filesystem access is therefore unnecessary.

One isolate owns one long-lived TruffleRuby `Context` and a bounded host executor (default maximum concurrency 5). Many invocations reuse the same Context and worker threads. Request identity is carried explicitly in the invocation envelope, never by physical thread identity. The runtime installs and clears invocation context at the execution boundary and snapshots/restores Ruby fiber/thread-local state so one invocation cannot inherit request-local state from a previous invocation.

Context-wide cancellation is treated as isolate failure: stop sending new requests to that Context, bring up a replacement, drain in-flight work when possible, then close the old Context.

## Rails request pool

Rails/Puma concurrency is configured independently from isolate concurrency:

```sh
RAILS_MIN_THREADS=50
RAILS_MAX_THREADS=300
```

Those are policy bounds, not a promise that every deployment should run 300 active DB-backed requests. Database, Redis, HTTP, memory, and downstream isolate capacity still need corresponding backpressure and pool sizing.

## Tests

CI proves all three paths:

- normal Rails on MRI;
- normal Rails on TruffleRuby;
- Rails-free Lambda code generation with ignored sibling handlers;
- Rails-free Graal generation with a single reusable Ruby universe and five worker threads;
- no generated endpoint `handler.rb` is tracked in Git.
