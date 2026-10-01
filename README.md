# ores-ror.rb

One repository, two build modes, one application contract.

## Invariant

The checkout is not edited to switch runtimes. Environment variables select the build:

```sh
# ordinary Rails application
ORES_BUILD_TARGET=rails bundle exec rails server

# Lambda/Graal artifact generation; no Rails boot
ORES_BUILD_TARGET=lambda ruby bin/build-runtime
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
- handler group / isolate pool
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
ruby bin/verify-routes
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

Lambda/Graal mode:

```text
HTTP/event
  -> shared route match
  -> shared middleware
  -> generated route/group wrapper
  -> committed routes/**/handler.rb
  -> shared application/business logic
```

Rails controllers and FaaS handlers therefore share semantics without requiring the Lambda/Graal runtime to boot Rails.

## Generated Lambda/Graal topology

The build step validates the committed route/controller contract and then generates URL-shaped wrappers:

```text
generated/lambda/routes/users/[id]/handler.rb
generated/lambda/routes/carts/[id]/handler.rb
generated/lambda/routes/orders/[id]/handler.rb
generated/lambda/routes/orders/[id]/cancel/handler.rb
...
```

It also emits optional grouped handlers:

```text
generated/lambda/groups/users/handler.rb
generated/lambda/groups/orders/handler.rb
generated/lambda/groups/system/handler.rb
...
```

Choose the active dispatch granularity at build time:

```sh
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=route ruby bin/build-runtime
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=group ruby bin/build-runtime
```

`route` gives one generated wrapper per URL route. `group` allows a larger isolate to load a family such as all order routes and switch on the matched route. Neither mode changes the Rails source tree.

The generated manifest records both sides of the contract, including the Rails controller/action, committed source handler, generated route handler, grouped handler, middleware, group, and isolate pool.

## Graal/TruffleRuby packaging

`graal/bootstrap.rb` loads the generated Lambda entrypoint and does not boot Rails. The runtime image contains the shared `lib/` application code, committed `routes/` handlers, and generated wrappers.

This means the same Git repository remains a normal Rails app while also producing independently deployable TruffleRuby/Graal route or grouped-handler artifacts.

## Rails concurrency contract

Rails remains one ordinary Rails application. Puma owns a bounded reusable request-thread pool. Request identity must never be inferred from `Thread.current` identity.

The Graal path follows the same semantic rule: long-lived contexts/threads may serve many requests, while request identity travels explicitly in the invocation envelope.

## CI

CI verifies all of the following:

- MRI Rails tests and server boot
- TruffleRuby Rails tests and server boot
- exact Rails-controller / committed-handler route parity
- per-route Lambda code generation
- grouped Lambda code generation
- no Rails boot in Lambda/Graal artifacts
- TruffleRuby AWS Lambda container execution
