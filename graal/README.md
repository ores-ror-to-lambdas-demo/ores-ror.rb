# Graal runtime profile

This directory is runtime glue for the Rails-free lambda build. It is **not** a Rails application and it never boots Rails.

Build first:

```sh
BUNDLE_WITHOUT=rails ORES_BUILD_TARGET=lambda ruby bin/build-runtime
```

`graal/bootstrap.rb` loads only `generated/lambda/entrypoint.rb`. Each generated route handler calls the matching `OresApp::Controllers::*` plain-Ruby controller and renders the matching Rails view source that was embedded during code generation.

The controller/action/view mapping comes from the same route contract used by ordinary Rails, but Lambda/Graal never requires `config/environment`, `Rails.application`, ActionController, ActionView, or the Rails router.

Every route has `generated/lambda/routes/.../handler.rb`. Grouped handlers are also generated so a supervisor may load a family such as `orders`, `users`, or `carts` into one isolate and switch between member routes. `ORES_LAMBDA_HANDLER_GRANULARITY=route|group` chooses the active generated dispatch strategy.

Generated files are ignored build artifacts under `generated/`.
