# ores-ror.rb

One repository, two build modes, one routing/controller/view contract.

## Hard invariant

Rails boots **only** in ordinary Rails server mode. Lambda/Graal never boots Rails.

```sh
# normal Rails/Puma application
ORES_BUILD_TARGET=rails bundle exec rails server

# generate Rails-free Lambda/Graal artifacts
BUNDLE_WITHOUT=rails ORES_BUILD_TARGET=lambda ruby bin/build-runtime
```

The checkout is unchanged between modes. `generated/` is build output and is ignored by Git.

## Shared source contract

`lib/ores_app/routes.rb` records each route's HTTP method/path, middleware, isolate pool, Rails controller/action, and Rails view. Normal Rails installs that contract into `Rails.application.routes`. Lambda codegen reads the same metadata at build time.

Rails controllers under `app/controllers/` are thin framework adapters. Actual controller behavior lives in the Rails-independent `OresApp::Controllers::*` classes. Both Rails and Lambda/Graal call those same plain-Ruby controller classes.

Rails views remain under normal `app/views/...json.erb` paths. During the lambda build, the matching view source is embedded into that route's generated `handler.rb`, so an isolate does not need ActionView or a Rails boot to render it.

## Generated Lambda filesystem

There is intentionally no authored top-level `routes/` handler tree. Codegen creates:

```text
generated/lambda/routes/
├── users/[id]/handler.rb
├── carts/[id]/handler.rb
├── checkout-sessions/[id]/handler.rb
├── products/[id]/handler.rb
├── orders/[id]/handler.rb
├── orders/[id]/cancel/handler.rb
├── accounts/[id]/handler.rb
├── inventory/[id]/handler.rb
├── recommendations/[id]/handler.rb
├── search/handler.rb
├── sessions/handler.rb
├── profiles/[id]/preferences/handler.rb
└── healthz/handler.rb
```

A generated file contains the exact source mapping and calls the corresponding plain-Ruby controller plus the build-embedded view:

```ruby
RAILS_CONTROLLER = "OrdersController"
CONTROLLER_PATH = "orders"
CONTROLLER = OresApp::Controllers::Orders
ACTION = :cancel
VIEW = "orders/cancel"
TEMPLATE = "...contents of app/views/orders/cancel.json.erb..."

def call(request)
  result = CONTROLLER.call(ACTION, request)
  OresApp::LambdaView.render(VIEW, TEMPLATE, result)
end
```

`RAILS_CONTROLLER` is provenance/build metadata. The lambda runtime does **not** load that Rails class. It calls `OresApp::Controllers::Orders`, which contains no Rails dependency.

## Execution paths

Normal Rails:

```text
HTTP
 -> Rails router
 -> OrdersController#cancel
 -> OresApp::Controllers::Orders.call(:cancel, request)
 -> app/views/orders/cancel.json.erb
 -> response
```

Lambda/Graal:

```text
HTTP/event
 -> generated route matcher
 -> generated/lambda/routes/orders/[id]/cancel/handler.rb
 -> OresApp::Controllers::Orders.call(:cancel, request)
 -> embedded app/views/orders/cancel.json.erb source
 -> response
```

The Lambda/Graal path has **no** `config/environment`, `Rails.application`, Rails router, ActionController, ActionView, initializer, Puma, or Rails boot.

## Route vs grouped handlers

Codegen always creates per-route handlers and also grouped handlers such as `generated/lambda/groups/orders/handler.rb`. Select the active dispatch topology with:

```sh
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=route ruby bin/build-runtime
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=group ruby bin/build-runtime
```

The group handler only switches among its generated route handlers; it does not introduce Rails.

## Graal/TruffleRuby

`graal/bootstrap.rb` loads `generated/lambda/entrypoint.rb` only. A warm TruffleRuby context loads the generated plain-Ruby runtime and can serve many requests. Rails is not installed in the custom Lambda image and is not booted in Graal contexts.

The Graal host continues to own privileged capabilities such as outbound data-API HTTP. Guest code receives the existing explicit host bridge rather than raw sockets/database access.

## CI proof

GitHub Actions proves all of these separately:

- MRI boots and serves the ordinary Rails app.
- TruffleRuby boots and serves the ordinary Rails app when `ORES_BUILD_TARGET=rails`.
- Route and grouped lambda codegen run with `BUNDLE_WITHOUT=rails`.
- Generated `handler.rb` files contain the expected controller/action/view mapping.
- Generated code contains no Rails runtime references.
- The TruffleRuby Lambda image explicitly fails if the Rails gem is installed.
- The Lambda runtime executes `/healthz` through the generated handler and returns `execution_mode=lambda`.
