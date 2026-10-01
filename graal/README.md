# Graal runtime profile

This directory is runtime glue for the Rails-independent build. It is **not** a second Rails application and it does **not** boot Rails.

Build first:

```sh
ORES_BUILD_TARGET=lambda bundle exec ruby bin/build-runtime
```

## Worker model

A worker is a TruffleRuby/Graal `Polyglot::InnerContext`, **not** an OS process. One `graal/server.rb` host process owns the HTTP listener and creates a dedicated context pool for each concrete committed `routes/**/handler.rb` identity.

```text
one TruffleRuby/Graal host process
└── shared Graal runtime/code-sharing domain
    ├── routes/healthz/handler.rb
    │   ├── inner context 0
    │   └── inner context 1
    ├── routes/users/[id]/handler.rb
    │   ├── inner context 0
    │   └── inner context 1
    └── routes/orders/[id]/handler.rb
        ├── inner context 0
        └── inner context 1
```

The pool key is the concrete handler path. A context may be kept warm and reused for later invocations of **that same handler**, but it is never reassigned to another handler. Each context processes at most one invocation at a time. The Ruby `Polyglot::InnerContext` API keeps a live context scoped to a block, so the current host implementation gives each live inner context one owning host thread; this is still one OS process, not prefork/process workers.

`ORES_GRAAL_CONTEXTS_PER_HANDLER` controls pool size. Pools are created lazily when their route is first invoked.

## Entrypoints

- `graal/server.rb` — single-process HTTP host + per-handler context pools.
- `graal/worker_cluster.rb` — worker/context pool implementation.
- `graal/context_isolation_smoke.rb` — direct proof that globals in one inner context do not appear in another.
- `graal/bootstrap.rb` — Lambda/Graal-Show compatible single-invocation bootstrap.

The build still generates both concrete route handlers and optional grouped Lambda dispatchers under `generated/lambda`. Grouped Lambda dispatch is a packaging/dispatch optimization; it does **not** change the Graal server rule that every concrete `handler.rb` has its own context pool.

Run the cluster locally with TruffleRuby JVM mode:

```sh
ORES_BUILD_TARGET=lambda bundle exec ruby bin/build-runtime
ORES_GRAAL_CONTEXTS_PER_HANDLER=2 bundle exec truffleruby --jvm graal/server.rb
```

Then inspect the host and initialized context pools:

```sh
curl http://127.0.0.1:3200/__ores/cluster
```

Responses from routed handlers include `x-ores-host-pid`, `x-ores-worker-context`, `x-ores-worker-pool`, and `x-ores-worker-invocations` so CI can prove that different handlers stay in different inner-context pools while sharing one host process.
