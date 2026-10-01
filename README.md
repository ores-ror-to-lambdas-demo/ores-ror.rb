# ores-ror.rb

One Rails application, two execution modes, one source of truth.

## The rule

There is no Graal-specific copy of the routes/controllers/business logic. `config/routes.rb`, the controllers, services, and middleware are the application in both modes.

1. **Rails/Puma** boots the repository conventionally on MRI (or directly on TruffleRuby).
2. **Graal supervisor mode** boots this exact Rails tree inside reusable TruffleRuby contexts owned by `ores-ror.infra`. Each request is sent through `Rails.application.call` as a Rack request.

The old generated `graal/handler.rb` and duplicate `graal/routes.json` model was intentionally removed.

## Request/concurrency model

Request identity is carried in the Rack request and `x-request-id`; it is never identified by `Thread.current`. A supervisor worker thread serves many requests over its lifetime. A warm Graal cell owns at most five reusable Rails/TruffleRuby contexts, so up to five requests can execute concurrently without sharing per-request Ruby state.

Guest Rails code cannot create threads or child processes in supervisor mode. Native/FFI and direct socket access are disabled by the host. The only database/network capability is the host `gs_http` bridge.

## HTTP database transport

`HttpDatabase` is the same service in both runtimes:

- ordinary Rails uses a bounded persistent `Net::HTTP` connection pool;
- Graal mode automatically uses `ORES_GS_HTTP`, the host-mediated HTTP bridge backed by a shared JDK `HttpClient` pool.

There is no PostgreSQL wire-protocol connection from the Rails application.

## CI

`.github/workflows/dual-runtime.yml` proves:

- Rails tests on MRI Ruby;
- the same Rails tests on TruffleRuby/GraalVM;
- the same checked-out Rails tree boots and serves Rack requests inside the Java/Graal supervisor;
- a separate capability probe for true `Engine.spawnIsolate(true)` Ruby support.

The final probe is deliberately separate because current GraalVM releases still do not list Ruby among supported Polyglot Native-Isolate languages. It must never silently downgrade an isolate request into an ordinary context.
