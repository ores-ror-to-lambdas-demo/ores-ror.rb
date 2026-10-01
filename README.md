# ores-ror.rb

One repository, two build modes, one route/middleware/business-logic source of truth.

## Invariant

The checkout is not edited to switch runtimes. Environment variables select the build:

```sh
# ordinary Rails application
ORES_BUILD_TARGET=rails bundle exec rails server

# lambda artifact generation; no Rails boot
ORES_BUILD_TARGET=lambda ruby bin/build-runtime
```

Generated lambda artifacts live under `generated/` and are intentionally ignored by Git.

## Shared application contract

`lib/ores_app/routes.rb` is Rails-independent and owns the route table, middleware list, handler ID, handler group, and isolate-pool key. `config/routes.rb` installs that same table into Rails. Both Rails controllers and generated lambda handlers call the same `lib/ores_app` dispatcher/business handlers.

Rails mode boots Rails normally. Lambda mode must never require `config/environment`, `Rails.application`, Rack dispatch, Rails initializers, or Puma.

## Lambda handler topology

Every route always gets its own generated handler:

```text
generated/lambda/routes/user/handler.rb
generated/lambda/routes/cart/handler.rb
generated/lambda/routes/order/handler.rb
generated/lambda/routes/cancel_order/handler.rb
...
```

Codegen also emits higher-level grouped handlers with a switch over the member routes:

```text
generated/lambda/groups/users/handler.rb
generated/lambda/groups/carts/handler.rb
generated/lambda/groups/orders/handler.rb
generated/lambda/groups/system/handler.rb
...
```

Choose the active dispatch layer at build time:

```sh
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=route ruby bin/build-runtime
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=group ruby bin/build-runtime
```

`route` is the default because one generated `handler.rb` per route is the smallest known-good lambda unit. `group` lets an isolate load a larger route family (for example all order routes) and switch on the matched route without changing source code.

The generated `manifest.json` records both handler paths for every route plus its middleware, group, and isolate pool. A supervisor can therefore pool isolates by route, group, privilege class, deployment generation, or another policy without asking Rails to route the request.

## Request flow

```text
HTTP -> shared route match -> shared middleware -> isolate-pool selection -> generated route/group handler -> shared business code
```

The Rails path is instead:

```text
HTTP -> Rails router generated from shared route table -> thin controller adapter -> shared dispatcher/middleware/business code
```

The two modes share application semantics, not Rails runtime state.

## Graal/TruffleRuby

`graal/bootstrap.rb` loads only `generated/lambda/entrypoint.rb`. It does not boot Rails. The Graal supervisor can keep pools of long-lived TruffleRuby contexts and multiplex many requests through the generated route/group handlers, subject to the supervisor's concurrency/lifetime policy.

## Tests

Rails tests remain under `test/`. No-Rails lambda tests live under `lambda-test/` so the lambda contract can explicitly assert that the `Rails` constant was never loaded.
