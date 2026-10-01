# ores-ror.rb

One repository, two runtime surfaces, one application contract.

## Invariant

The checkout is not edited to switch runtimes. Environment variables select the build:

```sh
# ordinary Rails application
ORES_BUILD_TARGET=rails bundle exec rails server

# Lambda/Graal artifact generation; no Rails boot
ORES_BUILD_TARGET=lambda bundle exec ruby bin/build-runtime
```

Generated artifacts live under `generated/` and are intentionally ignored by Git.

## Source layout

Rails stays conventional. Controllers remain under `app/controllers`, Rails views remain under `app/views`, and `config/routes.rb` is the Rails router.

The committed `routes/` tree is a separate deployment surface for FaaS/Graal handlers. It does **not** need to be co-located with Rails controllers or views.

```text
app/
├── controllers/
│   ├── application_controller.rb
│   ├── users_controller.rb
│   ├── carts_controller.rb
│   ├── orders_controller.rb
│   └── ...
└── views/
    └── ...

config/
└── routes.rb

routes/
├── users/
│   └── [id]/handler.rb
├── carts/
│   └── [id]/handler.rb
├── orders/
│   └── [id]/
│       ├── handler.rb
│       └── cancel/handler.rb
└── ...
```

The Rails and FaaS surfaces are adapters around the same shared application/business logic. The handler tree should not duplicate controllers or business rules.

## Shared route contract

`lib/ores_app/routes.rb` is Rails-independent and records, for every route:

- HTTP method and URL path
- logical handler ID
- middleware
- handler group / scheduling pool metadata
- Rails controller and action
- committed filesystem handler path

For example:

```text
GET /users/:id
├── Rails: UsersController#show
└── FaaS/Graal: routes/users/[id]/handler.rb
```

`config/routes.rb` installs the shared table into Rails. The route contract validator rejects duplicate routes, duplicate names, missing Rails controllers, missing committed handlers, and orphan committed handlers.

Run it directly without booting Rails:

```sh
bundle exec ruby bin/verify-routes
```

## Request flow

Rails mode:

```text
HTTP
  -> config/routes.rb
  -> UsersController#show / OrdersController#cancel / ...
  -> shared dispatcher + middleware
  -> committed routes/**/handler.rb
  -> shared application/business logic
```

Graal worker-server mode:

```text
HTTP
  -> one outer TruffleRuby/Graal host process
  -> shared route match
  -> pool keyed by exact routes/**/handler.rb path
  -> one Polyglot::InnerContext worker
  -> generated route wrapper
  -> committed routes/**/handler.rb
  -> shared application/business logic
```

Rails controllers and FaaS handlers therefore share semantics without requiring the Graal worker runtime to boot Rails.

## Generated Lambda/Graal topology

The build step validates the committed route/controller contract and then generates URL-shaped wrappers:

```text
generated/lambda/routes/users/[id]/handler.rb
generated/lambda/routes/carts/[id]/handler.rb
generated/lambda/routes/orders/[id]/handler.rb
generated/lambda/routes/orders/[id]/cancel/handler.rb
...
```

It also emits optional grouped Lambda dispatchers:

```text
generated/lambda/groups/users/handler.rb
generated/lambda/groups/orders/handler.rb
generated/lambda/groups/system/handler.rb
...
```

Choose the active Lambda dispatch granularity at build time:

```sh
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=route bundle exec ruby bin/build-runtime
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=group bundle exec ruby bin/build-runtime
```

`route` gives one generated wrapper per URL route. `group` gives Lambda/event packaging a larger dispatcher that can switch among a family of routes. **Grouped Lambda dispatch does not weaken the Graal worker boundary:** `graal/server.rb` always keys its context pools by the concrete `handler.rb` path.

The generated manifest records both sides of the contract, including the Rails controller/action, committed source handler, generated route handler, grouped handler, middleware, group, and Graal context-pool key.

## Graal worker model

A Graal worker means one TruffleRuby `Polyglot::InnerContext`, not an OS process.

```text
one OS process / TruffleRuby JVM host
└── shared Graal runtime and code-sharing domain
    ├── routes/healthz/handler.rb pool
    │   ├── Context 0
    │   └── Context 1
    ├── routes/users/[id]/handler.rb pool
    │   ├── Context 0
    │   └── Context 1
    └── routes/orders/[id]/handler.rb pool
        ├── Context 0
        └── Context 1
```

Rules:

- pool identity is the exact committed `handler.rb` path;
- a context is never reassigned across handler identities;
- a warm context may serve later requests for the same handler;
- each context handles at most one invocation at a time;
- pools are lazy and independently sized;
- outbound database HTTP goes through an outer-host bridge rather than application code choosing a different database implementation;
- values crossing context boundaries are materialized into receiving-context Ruby strings before native/C-extension codecs consume them;
- the current Ruby `Polyglot::InnerContext` API keeps each live context inside a block, so the implementation uses one owning **host thread per live context**, while still keeping the entire worker cluster in one OS process.

Configure pool size with `ORES_GRAAL_CONTEXTS_PER_HANDLER`.

```sh
ORES_BUILD_TARGET=lambda bundle exec ruby bin/build-runtime
ORES_GRAAL_CONTEXTS_PER_HANDLER=2 bundle exec truffleruby --jvm graal/server.rb
```

Inspect the live host and lazily initialized pools:

```sh
curl http://127.0.0.1:3200/__ores/cluster
```

Routed responses expose proof headers:

```text
x-ores-host-pid
x-ores-worker-model
x-ores-worker-context
x-ores-worker-pool
x-ores-worker-invocations
```

The Graal proof programs are deliberately layered:

- `graal/context_isolation_smoke.rb` proves two real inner contexts do not share Ruby global state.
- `graal/context_bridge_smoke.rb` proves an inner context can call an admitted outer-host `Method` bridge.
- `graal/worker_health_smoke.rb` executes the concrete health handler through its real context worker without the HTTP server.
- the GitHub Actions cluster smoke boots `graal/server.rb`, invokes multiple handler paths, and verifies same host PID + distinct handler context identities + same-handler warm reuse.

## AWS Lambda packaging

`graal/bootstrap.rb` loads the generated Lambda entrypoint and does not boot Rails. The runtime image contains the shared `lib/` application code, committed `routes/` handlers, and generated wrappers.

This means the same Git repository remains a normal Rails app while also producing independently deployable TruffleRuby/Graal handler artifacts.

## Local deployment with ores-compose

`.ores-compose.yaml` starts both surfaces as native host services:

- Rails/Puma at `127.0.0.1:3100`;
- one TruffleRuby/Graal host at `127.0.0.1:3200`, with context workers inside that process.

If the repository is already cloned:

```sh
./bin/local-install-mri.sh
./bin/local-install-truffleruby.sh

/path/to/ores-compose check .ores-compose.yaml
/path/to/ores-compose plan .ores-compose.yaml
ORES_COMPOSE_SKIP_ZED_PKG=true ORES_COMPOSE_SKIP_RPC_GEN=true \
  /path/to/ores-compose up .ores-compose.yaml
```

For a fresh machine/workspace, `bin/clone-build-deploy-local.sh` clones and builds `ORESoftware/ores-compose`, clones this repository, installs both Ruby dependency sets, verifies/builds the route runtime, validates the compose plan, and finally runs `ores-compose up`.

```sh
bash bin/clone-build-deploy-local.sh
```

Set `CHECK_ONLY=true` to stop after clone/build/check/plan instead of starting the attached stack.

## Rails concurrency contract

Rails remains one ordinary Rails application. Puma owns a bounded reusable request-thread pool. Request identity must never be inferred from `Thread.current` identity.

The Graal path follows the same semantic rule: long-lived contexts/threads may serve many requests, while request identity travels explicitly in the invocation envelope.

## CI

CI verifies all of the following:

- MRI Rails tests and real Puma server boot;
- TruffleRuby Rails tests and real Puma server boot;
- exact Rails-controller / committed-handler route parity;
- per-route Lambda code generation;
- grouped Lambda code generation;
- no Rails boot in Lambda/Graal artifacts;
- direct TruffleRuby `Polyglot::InnerContext` state isolation;
- admitted host callback interop into an inner context;
- direct execution of a concrete route handler inside its context worker;
- one Graal host PID shared by multiple handler pools while handler contexts remain distinct;
- warm reuse only within the same handler pool;
- TruffleRuby AWS Lambda container execution.
