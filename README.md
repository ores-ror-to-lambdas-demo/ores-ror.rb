# ores-ror.rb

A conventional Rails reference server whose route contract can also be executed as admitted TruffleRuby lambdas on Graal Show.

## Runtime modes

1. **Rails reference mode** — ordinary Rails/Puma app for local development and route/response parity tests.
2. **Graal isolate mode** — `graal/handler.rb` is the single-source, `json-string-v1` TruffleRuby artifact admitted by `graal-show/gs-compiler` and executed by the in-process supervisor in `ores-ror.infra`.

Rails itself is intentionally not smuggled into the untrusted guest context. Graal Show's `gs-graal-guest-v1` profile accepts one Ruby source file and no Gem/Bundler dependency graph. The isolate handler therefore mirrors the Rails route contract while using only `JSON` plus the capability-scoped `gs_http` support API.

## Concurrency contract

Request identity is explicit (`request_id` / `invocation_id`). `Thread.current` may be used only for diagnostics; a pool thread is reused by many requests and must never own request state. Guest code cannot create threads. The host supervisor owns a fixed pool of at most five execution threads per isolate and creates a fresh Graal `Context` for every request while sharing the isolate `Engine` and cached `Source`.

## Database access

There is no PostgreSQL wire-protocol adapter and no `pg` gem. Application data goes through an HTTP Data API. Rails reference mode pools persistent HTTP clients; isolate mode calls `gs_http`, whose host-side Java `HttpClient` is shared for the warm isolate and therefore reuses HTTP connections.

Environment:

- `DATA_API_URL` — e.g. `https://data.example.internal/v1`
- `DATA_API_TOKEN` — optional bearer token in Rails reference mode. Production isolate deployments should inject authorization at the trusted host/support-api layer rather than exposing arbitrary environment access to guest Ruby.

## Routes

The demo includes users, carts, checkout sessions, products, orders, order cancellation, accounts, inventory, recommendations, search, sessions, and health endpoints.
