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

`lib/ores_app/routes.rb` is Rails-independent and owns the route table, middleware list, handler ID, handler group, and isolate-pool key. Every declared URL also owns a committed filesystem handler under `routes/`. `config/routes.rb` installs the same route table into Rails, while both Rails and generated lambda/Graal dispatch execute the committed route handler before entering shared business code.

Rails mode boots Rails normally. Lambda mode must never require `config/environment`, `Rails.application`, Rack dispatch, Rails initializers, or Puma.

## Source route filesystem

Routes are real source directories, not only rows in `lib/ores_app/routes.rb`. Dynamic URL parameters use `[name]` in the filesystem so the repository remains portable across operating systems; for example `:id` maps to `[id]`.

```text
routes/
├── users/
│   └── [id]/
│       └── handler.rb
├── carts/
│   └── [id]/
│       └── handler.rb
├── checkout-sessions/
│   └── [id]/
│       └── handler.rb
├── products/
│   └── [id]/
│       └── handler.rb
├── orders/
│   └── [id]/
│       ├── handler.rb
│       └── cancel/
│           └── handler.rb
├── accounts/
│   └── [id]/handler.rb
├── inventory/
│   └── [id]/handler.rb
├── recommendations/
│   └── [id]/handler.rb
├── search/handler.rb
├── sessions/handler.rb
├── profiles/
│   └── [id]/preferences/handler.rb
└── healthz/handler.rb
```

`OresApp::Routes.handler_relative_path` deterministically maps each route-table entry to its source handler. Rails tests assert the complete mapping, and lambda codegen aborts if any declared route lacks its committed `handler.rb`.

## Lambda handler topology

Every source route gets its own URL-shaped generated handler wrapper:

```text
generated/lambda/routes/users/[id]/handler.rb
generated/lambda/routes/carts/[id]/handler.rb
generated/lambda/routes/orders/[id]/handler.rb
generated/lambda/routes/orders/[id]/cancel/handler.rb
...
```

The generated wrapper calls the corresponding committed source handler. Codegen also emits higher-level grouped handlers with a switch over the member routes:

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

The generated `manifest.json` records the committed source handler, generated route handler, grouped handler, middleware, group, and isolate pool for every route. A supervisor can therefore pool isolates by route, group, privilege class, deployment generation, or another policy without asking Rails to route the request.

## Request flow

```text
HTTP -> shared route match -> shared middleware -> isolate-pool selection -> committed route handler -> shared business code
```

The Rails path is:

```text
HTTP -> Rails router generated from shared route table -> thin controller adapter -> shared dispatcher/middleware -> committed route handler -> shared business code
```

The lambda/Graal path is:

```text
HTTP/event -> shared route match -> shared middleware -> generated route/group wrapper -> committed route handler -> shared business code
```

The two modes share application semantics and source handlers, not Rails runtime state.

## Graal/TruffleRuby

`graal/bootstrap.rb` loads only `generated/lambda/entrypoint.rb`. It does not boot Rails. The Graal supervisor can keep pools of long-lived TruffleRuby contexts and multiplex many requests through the generated route/group handlers, subject to the supervisor's concurrency/lifetime policy.

## Tests

Rails tests remain under `test/`. No-Rails lambda tests live under `lambda-test/` so the lambda contract can explicitly assert that the `Rails` constant was never loaded. CI additionally verifies the committed route tree and the URL-shaped generated route tree.
