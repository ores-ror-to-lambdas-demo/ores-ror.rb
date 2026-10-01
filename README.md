# ores-ror.rb

One normal Rails application, plus generated Rails-free Lambda/Graal adapters.

## Hard runtime boundary

Rails boots **only** in normal Rails mode.

```text
normal Rails/Puma
  -> boots config/environment.rb
  -> Rails.application
  -> normal Rails controllers/views/middleware

Lambda / Graal
  -> never loads config/environment.rb
  -> never initializes Rails.application
  -> Rails gem is excluded
  -> statically reads Rails source conventions
  -> runs generated Rails-free handlers
```

That boundary applies to code generation too: Lambda/Graal generation does not boot Rails.

## Rails remains canonical

`config/routes.rb` is the route source of truth. Controllers and views use normal Rails paths:

```text
app/controllers/
└── users/
    └── show/
        ├── endpoint_controller.rb   # Users::Show::EndpointController#show
        └── handler.rb               # GENERATED; gitignored

app/views/
└── users/
    └── show/
        └── endpoint/
            └── show.html.erb        # normal Rails view path
```

Shared layouts, partials, helpers, mailers, jobs, models, and other Rails application code remain in their normal Rails locations.

The Rails app uses the normal full controller stack rather than API-only mode.

## Rails-free convention discovery

For a Lambda/Graal build:

```sh
BUNDLE_WITHOUT=rails ORES_BUILD_TARGET=lambda ruby bin/build-runtime
```

The generator uses Ruby's static parser to read `config/routes.rb`; it does not require `config/environment.rb` and aborts if Rails has already been loaded.

For each statically resolvable route it:

1. reads the literal HTTP verb/path and conventional `to: "controller#action"`;
2. resolves `app/controllers/<controller>_controller.rb` by Rails filesystem convention;
3. verifies the action method exists in that source file without loading it;
4. derives the Rails controller class name from the path;
5. derives `app/views/<controller>/<action>.*` as the conventional view lookup;
6. writes an ignored `handler.rb` beside the endpoint controller;
7. emits a Rails-free route table and Lambda entrypoint under ignored `generated/lambda/`.

The current demo deliberately fails closed on dynamic routing constructs such as `resources`, `namespace`, `scope`, `match`, and mounts rather than booting Rails to interpret them. Those constructs should be added to the static compiler explicitly.

## Generated handler sidecars

A generated file such as:

```text
app/controllers/users/show/handler.rb
```

defines the path-compatible constant:

```ruby
Users::Show::Handler
```

and records:

- `CONTROLLER_PATH`
- `CONTROLLER_CLASS`
- `CONTROLLER_FILE`
- `ACTION`
- `VIEW_LOGICAL_PATH`
- `VIEW_FILES`

Its executable path is Rails-free:

```ruby
Users::Show::Handler.call(request)
```

The handler never instantiates a Rails controller and never references the Rails constant. It adapts the statically discovered endpoint identity into the shared Rails-free business/runtime layer.

## Views

Normal Rails mode resolves views normally through Rails.

Lambda/Graal records the same logical view path and matching template files during static generation. The manifest also records `app/views` as the shared view root so generated runtimes can package templates, partials, and layouts without initializing Rails.

## Lambda image

The Lambda image installs with:

```text
BUNDLE_WITHOUT=rails:test
```

before running codegen. CI asserts the Rails gem is absent, generates the handlers, scans generated Ruby for Rails boot references, and then exercises the Lambda adapter.

## Concurrency

Normal Rails uses its bounded reusable Puma pool.

Graal isolates use one long-lived TruffleRuby Context per isolate with a small bounded host-owned thread pool. Request identity is explicit and is never physical thread identity.
