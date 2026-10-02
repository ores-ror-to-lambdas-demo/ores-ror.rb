# ores-ror.rb

One application repository, two execution modes, one route/middleware/business-logic source of truth.

## Repository boundary

This repository owns application semantics:

- `config/routes.rb` — Rails routing and per-route middleware authority;
- `routes/**/handler.rb` — physical route execution adapters;
- `app/controllers/**`, `app/models/**`, `app/views/**` — conventional Rails MVC source;
- `lib/ores_app/**` — shared Rails-free dispatcher, middleware, handlers, and HTTP data boundary;
- `lib/ores_build/**` + `bin/build-runtime` — static compiler;
- `generated/**` — ephemeral Lambda/Graal artifacts.

Runtime/deployment adapters are intentionally **not** stored here. They live in the companion repository:

`ores-ror-to-lambdas-demo/ores-ror.infra`

That repo owns `graal/**`, `aws-lambda/**`, hosting profiles, Docker/runtime adapters, and deployment tooling.

## Build modes

Normal Rails needs only this checkout:

```sh
ORES_BUILD_TARGET=rails bundle exec rails server
```

Lambda application artifacts are generated here without Rails:

```sh
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=route ruby bin/build-runtime
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=group ruby bin/build-runtime
```

Graal generation additionally consumes the infra-owned bootstrap:

```sh
ORES_INFRA_ROOT=../ores-ror.infra \
  ORES_BUILD_TARGET=graal \
  truffleruby bin/build-runtime
```

The compiler fails closed if that bootstrap is unavailable.

## Authority invariant

Infra consumes the application contract; infra does not redefine it.

```text
config/routes.rb
      │
      ├── route + middleware metadata
      ├── controller/action mapping
      └── route/group mapping
      │
      ▼
lib/ores_build/static_routes.rb
      │
      ▼
generated/lambda + generated/graal
      │
      ├──────────────┐
      ▼              ▼
AWS Lambda infra   Graal infra
```

Both Rails and generated Graal/Lambda paths therefore continue to execute the same route middleware chain, committed route adapter, models, views, and business handlers.

## Source route filesystem

Dynamic URL parameters use `[name]` in the filesystem. The current committed surface contains at least 15 routes, including:

```text
routes/
├── users/[id]/handler.rb
├── users/[id]/activity/handler.rb
├── carts/[id]/handler.rb
├── checkout-sessions/[id]/handler.rb
├── products/[id]/handler.rb
├── orders/[id]/handler.rb
├── orders/[id]/receipt/handler.rb
├── orders/[id]/cancel/handler.rb
├── accounts/[id]/handler.rb
├── inventory/[id]/handler.rb
├── recommendations/[id]/handler.rb
├── search/handler.rb
├── sessions/handler.rb
├── profiles/[id]/preferences/handler.rb
└── healthz/handler.rb
```

## Generated topology

Route-level and group-level build artifacts remain in this app checkout:

```text
generated/
├── lambda/
│   ├── manifest.json
│   ├── routes/...
│   └── groups/...
└── graal/
    ├── manifest.json
    ├── common.rb
    ├── routes/...
    └── groups/...
```

They are generated and ignored by Git.

## Cross-runtime proof

CI executes normal Rails and Rails-free Graal against all application routes in both JSON and HTML. It compares the exported contracts exactly, including per-route middleware chains and middleware-derived response headers.

The migration of runtime folders to `ores-ror.infra` is guarded by the same tests: app CI checks out the infra repo explicitly, asserts this app checkout contains neither `graal/` nor `aws-lambda/`, then reruns the complete matrix.
