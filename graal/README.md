# Graal runtime profile

This directory is runtime glue for the lambda build. It is **not** a second Rails application and it does **not** boot Rails.

Build first:

```sh
ORES_BUILD_TARGET=lambda ruby bin/build-runtime
```

`graal/bootstrap.rb` loads `generated/lambda/entrypoint.rb`, which dispatches through generated route/group handlers and the Rails-independent `lib/ores_app` code.

Every route has a generated `handler.rb`. Grouped handlers are also generated so a supervisor may load a family such as `orders`, `users`, or `carts` into one isolate and switch between member routes. `ORES_LAMBDA_HANDLER_GRANULARITY=route|group` chooses the active generated dispatch strategy.

The generated files are build artifacts under `generated/` and are not tracked by Git.
