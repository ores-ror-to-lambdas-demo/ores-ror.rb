# ores-ror.rb

One normal Rails application, with Lambda/Graal handlers generated from the Rails endpoint layout.

## Core invariant

Rails remains Rails. It boots normally through `config/environment.rb`, routes through `config/routes.rb`, and uses normal controllers, models, middleware, jobs, mailers, helpers, views, and gems.

FaaS builds do **not** put Rails inside each Lambda/isolate. Instead, every endpoint has a normal tracked Rails controller directory, and codegen writes an untracked `handler.rb` beside that controller.

## Endpoint layout

```text
app/controllers/
├── application_controller.rb
├── ores_endpoint_controller.rb
├── users/
│   └── show/
│       ├── endpoint_controller.rb   # tracked Rails controller
│       ├── handler.rb               # GENERATED; gitignored
│       └── show.html.erb            # optional co-located view
├── orders/
│   ├── show/
│   │   ├── endpoint_controller.rb
│   │   └── handler.rb
│   └── cancel/
│       ├── endpoint_controller.rb
│       └── handler.rb
└── ...

app/views/                         # shared views/layouts still live here
config/routes.rb                   # canonical Rails router
```

Each endpoint folder is a real Rails namespace. For example:

```text
GET /users/:id
  -> users/show/endpoint#call
  -> app/controllers/users/show/endpoint_controller.rb
  -> app/controllers/users/show/handler.rb   # generated for FaaS only
```

The generated `handler.rb` is intentionally excluded from version control via `/app/controllers/**/handler.rb`.

## Views

Endpoint-specific views may be placed beside the endpoint controller. Each endpoint controller calls `prepend_view_path __dir__` when the Rails controller stack supports view paths, so a view-enabled Rails application can resolve those files first.

Shared templates, partials, and layouts remain under normal Rails `app/views`.

## Lambda build

```sh
ORES_BUILD_TARGET=lambda ruby bin/build-runtime
```

The generator:

1. validates that every route has a tracked `endpoint_controller.rb`;
2. writes one generated `handler.rb` beside every endpoint controller;
3. writes only aggregate Lambda metadata/entrypoints under ignored `generated/lambda/`;
4. records the Rails controller, endpoint directory, generated handler path, group, and isolate-pool key in the manifest.

The generated handler calls the same Rails-independent business handler used by the normal Rails request path, without booting Rails.

## Request flow

Normal Rails:

```text
HTTP
 -> config/routes.rb
 -> endpoint-specific Rails controller
 -> shared dispatcher/middleware/business code
```

Lambda/Graal:

```text
HTTP/event
 -> generated Lambda/Graal entrypoint
 -> generated handler.rb beside the Rails controller
 -> shared dispatcher/middleware/business code
```

There is no tracked parallel `routes/` source tree.

## Concurrency

Rails uses a bounded reusable Puma pool. Production defaults to 50–300 threads, configurable with `RAILS_MIN_THREADS` and `RAILS_MAX_THREADS`.

Graal isolates use one long-lived Ruby Context per isolate with a bounded host-owned worker pool. Request identity is explicit and is never physical thread identity.
