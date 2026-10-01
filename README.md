# ores-ror.rb

One normal Rails application, plus generated Rails-free Lambda/Graal adapters.

## Rails is the source of truth

The application follows Rails conventions first. There is no parallel ORES route table.

`config/routes.rb` is the only route definition. Controllers live under `app/controllers` using normal Rails namespacing and normal action names:

```text
app/controllers/
├── application_controller.rb
├── ores_endpoint_controller.rb
├── users/
│   └── show/
│       ├── endpoint_controller.rb   # Users::Show::EndpointController#show
│       └── handler.rb               # GENERATED; gitignored
├── orders/
│   ├── show/
│   │   ├── endpoint_controller.rb   # Orders::Show::EndpointController#show
│   │   └── handler.rb
│   └── cancel/
│       ├── endpoint_controller.rb   # Orders::Cancel::EndpointController#cancel
│       └── handler.rb
└── ...

app/views/
└── users/show/endpoint/
    └── show.html.erb                 # normal Rails view lookup
```

Shared layouts, partials, and templates stay under normal `app/views` paths.

## Convention-over-configuration codegen

For a Lambda build, the generator boots Rails **only at build time** and asks Rails for its real route set:

```sh
RAILS_ENV=test ORES_BUILD_TARGET=lambda bundle exec ruby bin/build-runtime
```

For every named controller route it:

1. reads controller/action from `Rails.application.routes`;
2. constantizes the normal Rails controller class;
3. uses the action method's source location to find the real controller directory;
4. writes an ignored `handler.rb` beside that controller;
5. derives Rails' conventional logical view path from `controller_path/action`;
6. records matching `app/views/<controller_path>/<action>.*` files;
7. derives group/pool defaults from the top-level controller namespace;
8. emits the Rails-free route table and aggregate Lambda entrypoint under ignored `generated/lambda/`.

There is no source-level route duplication to synchronize.

## Generated handler contract

A generated handler records the Rails controller path, controller class, action, conventional view logical path, and discovered view files.

Its FaaS `call(request)` path invokes the Rails-independent endpoint logic without loading Rails.

If Rails is present, `rails_rack(env)` resolves the canonical Rails controller and calls `.action(ACTION).call(env)`. This lets tooling hand control back to Rails rather than reproducing controller semantics.

## Views

Rails itself uses normal `app/views/<controller_path>/<action>.*` lookup. Generated handlers carry that same logical path and build-time file list, so a Lambda renderer can package or compile the templates Rails would resolve.

We intentionally do not alter Rails view paths.

## Runtime packaging

Rails exists only in the code-generation stage. The AWS Lambda image uses a multi-stage build:

```text
codegen stage
  Rails + TruffleRuby
  -> inspect Rails routes/controllers/views
  -> generate handler.rb + manifest

runtime stage
  TruffleRuby
  Rails excluded
  -> copy generated artifacts
  -> run Lambda
```

The Graal worker consumes the same generated contract. Rails remains one ordinary Rails server and is never copied into each Lambda/isolate.

## Concurrency

Rails uses a bounded reusable Puma pool. Graal isolates use one long-lived TruffleRuby Context per isolate with a small bounded host-owned thread pool. Request identity is explicit and is never physical thread identity.
