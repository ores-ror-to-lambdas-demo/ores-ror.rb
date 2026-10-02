# Graal runtime profile

This is the Rails-free Graal/TruffleRuby deployment profile. It does not initialize `Rails.application`.

- one host OS process may own one shared Graal engine;
- every concrete route gets exactly one long-lived Ruby context/isolate;
- every route group gets exactly one long-lived Ruby context/isolate;
- each context multiplexes requests over at most 5 host threads;
- a worker is a host execution thread entering a context, not another OS process or another context;
- mutable Ruby state is context-local while compiled/source material may be shared read-only by the engine;
- guest-created threads, filesystem access, child processes, raw sockets, and native FFI remain disabled;
- data access uses the host HTTP capability.

`config/routes.rb` is the Rails routing authority. Committed `routes/**/handler.rb` files are the execution-adapter authority. Lambda/Graal builds validate a one-to-one mapping before generation.

```sh
ORES_BUILD_TARGET=lambda ruby bin/build-runtime
ORES_BUILD_TARGET=graal ruby bin/build-runtime
```

Normal Rails mode boots Rails conventionally. Lambda/Graal mode uses the generated Rails route contract plus shared middleware without booting the Rails application.
