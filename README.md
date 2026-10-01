# ores-ror.rb

One repository, three execution targets, one physical route tree.

## Runtime targets

```sh
# ordinary Rails application
ORES_BUILD_TARGET=rails bundle exec rails server

# AWS Lambda artifacts; Rails does not boot
ORES_BUILD_TARGET=lambda ruby bin/build-runtime

# Graal/TruffleRuby worker artifact; Rails does not boot
ORES_BUILD_TARGET=graal ruby bin/build-runtime
```

Generated artifacts live under `generated/` and are ignored by Git. They are build products, not a second maintained application.

## The filesystem is the route authority

HTTP routes are committed as real directories with real `handler.rb` files:

```text
routes/
├── users/
│   └── [id]/
│       └── handler.rb            # GET /users/:id
├── carts/
│   └── [id]/
│       └── handler.rb            # GET /carts/:id
├── checkout-sessions/
│   └── [id]/
│       └── handler.rb            # POST /checkout-sessions/:id
├── products/
│   └── [id]/
│       └── handler.rb            # GET /products/:id
├── orders/
│   ├── handler.rb                # higher-level orders group handler
│   └── [id]/
│       ├── handler.rb            # GET /orders/:id
│       └── cancel/
│           └── handler.rb        # POST /orders/:id/cancel
├── accounts/[id]/handler.rb
├── inventory/[id]/handler.rb
├── recommendations/[id]/handler.rb
├── search/handler.rb
├── sessions/handler.rb
├── profiles/[id]/preferences/handler.rb
└── healthz/handler.rb
```

`[id]` is the cross-platform filesystem spelling of the Rails-style `:id` segment. `OresApp::Routes` derives the URL path from the committed source path; handlers do not point at imaginary route files.

Each leaf handler registers its HTTP verb, route name, middleware group/pool metadata, and the executable block for that endpoint. The request behavior itself lives in the physical `handler.rb`. There is no central handler-name switch.

`config/routes.rb` asks `OresApp::Routes` to discover this tree and install those routes into Rails. The build tool discovers the same tree for Lambda and Graal.

## Lambda topology

Every physical leaf route gets a generated deployment handler under `generated/lambda/routes/`. Codegen also emits grouped deployment handlers. A committed higher-level group handler can exist in the physical tree; `routes/orders/handler.rb` demonstrates this for the order family.

```sh
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=route ruby bin/build-runtime
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=group ruby bin/build-runtime
```

The generated manifest records each HTTP path together with its committed `source_handler`, generated route handler, group, and isolate-pool key.

## Graal/TruffleRuby

`ORES_BUILD_TARGET=graal` flattens the shared runtime plus the committed `routes/**/handler.rb` sources into one immutable generated Ruby source. The Graal worker path does not boot Rails and does not need runtime filesystem discovery. The supervisor can share one Graal Engine/source generation while giving each invocation a fresh restricted Ruby Context on a reusable host thread.

## Invariants

- Rails, Lambda, and Graal execute the same committed endpoint handlers.
- Rails boots only for Rails server mode.
- Generated FaaS code is untracked and reproducible from the physical route tree.
- `Thread.current` is never request identity.
- The filesystem route validator rejects unregistered handler files, missing registered files, duplicate route names, duplicate verb/path pairs, and route/source path mismatches.
- HTTP Data API access remains shared infrastructure rather than a PostgreSQL TCP connection from route code.

`test/filesystem_routes_test.rb` locks the current 13-route filesystem contract so CI fails if the route tree and runtime surfaces diverge.
