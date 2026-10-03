# ores-ror.rb

One Rails application source tree, with normal Rails execution plus generated Rails-free Lambda/Graal execution.

## Non-negotiable runtime boundary

**Rails only boots in Rails mode.**

Normal Rails mode is a normal Rails application:

```sh
ORES_BUILD_TARGET=rails bundle exec rails server
```

It uses the Rails router, controllers, callbacks, models, Action View, initializers, and Puma normally. Production Puma uses a bounded adaptive pool: 30 warm threads, up to 40 regular request threads, with I/O-bound headroom to a hard default ceiling of 50.

Lambda and Graal are compilation/runtime targets derived from the Rails source tree. They do **not** boot `Rails.application`, Action Controller, Action View, Puma, or Rails initializers.

## Rails remains the source of truth

Application semantics live in ordinary Rails locations:

- `config/routes.rb` — sole route and per-route middleware authority;
- `app/controllers/**` — controller/action source;
- `app/models/**` — model source;
- `app/views/**` — shared Rails views;
- co-located endpoint views under the controller hierarchy when useful;
- `lib/ores_app/**` — portable application/runtime helpers;
- `lib/ores_build/**` + `bin/build-runtime` — static Rails-to-runtime compiler.

There is **no** committed parallel `routes/**/handler.rb` tree and no `# ores-route` annotation layer.

The compiler statically reads `config/routes.rb` without booting Rails, resolves the corresponding controller/action/model/views by Rails filesystem convention, and fails closed on unsupported or ambiguous input.

## Controller-adjacent generated handler.rb

Each portable endpoint uses a dedicated controller directory. During Lambda/Graal generation the compiler creates an ignored `handler.rb` beside that controller.

Example:

```text
app/controllers/
└── users/
    └── show/
        ├── endpoint_controller.rb   # tracked Rails source
        └── handler.rb              # GENERATED, gitignored
```

The generated sidecar is deliberately small. It records the resolved controller/action/view contract and calls the co-located controller through `call_ores_action`. It is not an independent source of routing truth.

Generated sidecars:

- are recreated from Rails source;
- are ignored by Git;
- reject replacement through symlinks;
- may not silently overwrite a non-generated file.

## Views

Normal Rails mode renders through Action View exactly as a Rails application normally would.

For Lambda/Graal, ERB templates are compiled **at build time** into plain-Ruby renderer lambdas and embedded into the generated artifact. Guest execution does not load Action View or an ERB compiler and does not read application view files at request time.

Shared views can stay in `app/views/**`. Endpoint-specific views can follow the endpoint/controller hierarchy used by this demo.

## Build targets

Lambda:

```sh
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=route ruby bin/build-runtime
```

or:

```sh
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=group ruby bin/build-runtime
```

Graal:

```sh
ORES_INFRA_ROOT=../ores-ror.infra ORES_BUILD_TARGET=graal truffleruby bin/build-runtime
```

The Graal bootstrap and hosting implementation belong to the companion repository:

`ores-ror-to-lambdas-demo/ores-ror.infra`

This repository intentionally contains neither `graal/` nor `aws-lambda/` deployment/runtime folders.

## Generated topology

```text
generated/
├── lambda/
│   ├── manifest.json
│   ├── common.rb
│   ├── routes/...
│   └── groups/...
└── graal/
    ├── manifest.json
    ├── common.rb
    ├── routes/...
    └── groups/...
```

Generated artifacts are ephemeral and ignored by Git.

They embed only the portable Ruby needed for the selected route/group: controller/model source, compiled view renderers, portable routing/middleware/runtime code, and the generated controller-adjacent sidecar contract.

## Request flow

Rails mode:

```text
HTTP
  -> Rails router
  -> Rails controller/action
  -> Rails callbacks + portable route middleware
  -> model/business logic
  -> Action View
  -> Rails response
```

Graal/Lambda mode:

```text
request/event
  -> generated route table
  -> generated controller-adjacent handler
  -> same controller action source
  -> portable middleware
  -> model/business logic
  -> build-time-compiled view renderer
  -> runtime response
```

The generated runtime uses a small plain-Ruby request/response/controller compatibility layer; it is not Rails.

## Threading and request state

The two execution modes intentionally have different hosting models:

- **Rails/Puma:** normal Rails server execution with a bounded adaptive pool: 30 warm threads, 40 regular capacity, and I/O-bound headroom up to 50 total request-processing threads.
- **Graal:** one long-lived TruffleRuby `Context` per route or route-group isolate, with execution multiplexed over one bounded process-wide host thread pool shared by all isolates; each isolate separately admits at most 5 concurrent entries.
- **Lambda:** normal Lambda execution-environment concurrency around generated Rails-free Ruby.

Request identity must never equal physical thread identity.

Portable Graal request execution is wrapped by `OresApp::ThreadStateBoundary`, which snapshots and restores both Ruby `Thread#[]`/fiber-local state and true thread variables before a host worker is reused. Guest-created threads remain disallowed by the Graal host.

Rails and third-party Rails gems remain entirely in Rails mode; their thread-local/execution-local behavior is therefore a Rails/Puma compatibility concern, not something imported into the Graal guest.

## Graal contract

The generated Graal manifest declares:

- one process-shared Graal `Engine`;
- one long-lived Ruby `Context` per route/group isolate;
- `host_thread_pool_scope: process-shared`;
- host OS threads are reusable across different isolate Contexts with no per-isolate thread affinity;
- the global pool size is an infra/runtime setting rather than multiplied by isolate count;
- execution/admission remains bounded to 5 per isolate;
- explicit per-invocation request state;
- thread identity is not request identity;
- Rails boot disabled;
- guest filesystem, raw sockets, native FFI, child processes, and guest-created threads disabled;
- database/network access through the narrow host HTTP capability.

The infra supervisor additionally starts embedded TruffleRuby with multithreaded Context access explicitly enabled while keeping guest thread creation disabled.

## Lambda packaging boundary

The final Lambda runtime image contains generated Lambda artifacts plus infra-owned runtime adapters and a minimal Rails-free Gemfile.

It does **not** contain the Rails application source tree and does not install the Rails, Action Pack, or Action View gems.

## Cross-runtime proof

CI verifies:

- normal Rails on MRI;
- normal Rails on TruffleRuby;
- Rails-free static code generation;
- generated sidecars are ignored and convention-derived;
- Rails-free Lambda image construction and invocation;
- shared-thread-pool warm-Context request-state cleanup;
- route/group Graal generation;
- exact Rails-vs-Graal behavior across every demo route in JSON and HTML;
- symlink/path/output trust-boundary failures are rejected.

The purpose of the demo is not to replace Rails semantics in Rails mode. It is to preserve normal Rails as the authoring/runtime baseline while producing explicit, testable Rails-free execution artifacts for Lambda and Graal.


## Rails adaptive concurrency

Rails server mode runs directly under Puma 8. The default process-level request concurrency model is intentionally bounded:

- 30 warm reusable request threads;
- ordinary demand may grow the regular pool to 40;
- Rails data-backed requests are classified as I/O-bound before controller execution;
- Puma may create up to 10 additional I/O processor threads while those requests wait, for a hard default ceiling of 50 request-processing threads;
- excess threads are reclaimed when demand falls;
- `fiber_per_request` gives each request a clean Fiber so fiber-local state cannot leak when a worker thread is reused.

This is a **reused thread pool**, not a newly spawned thread for every request. An in-flight synchronous Rack request still occupies one pooled Puma processor thread; the I/O classification makes Puma replace I/O-waiting capacity instead of allowing slow HTTP calls to consume all regular request capacity. The Data API connection pool defaults to the same 50-request ceiling and uses persistent keep-alive sessions with bounded connect/read/write timeouts and no hidden Net::HTTP retries.

Run Puma directly so the Puma 8 concurrency contract is active:

```sh
ORES_BUILD_TARGET=rails bundle exec puma -C config/puma.rb config.ru
```


## Rails async I/O fan-out

Rails mode also includes bounded fiber-scheduled fan-out for controllers that have multiple independent outbound operations.

`OresApp::HttpDatabase.parallel_requests` uses Async's Fiber scheduler in Rails mode **when the Ruby runtime exposes `Fiber.scheduler`**. The default per-request fan-out limit is 4 and the helper rejects more than 16 operations in one batch. The existing persistent HTTP connection pool remains the transport, so fan-out reuses keep-alive `Net::HTTP` sessions instead of creating one client per operation.

The product endpoint is the concrete demo: it requests product data and inventory independently, concurrently in Rails, then renders the combined result. The same controller source runs in generated Lambda/Graal form; when Async is not bundled there, the helper executes the same request set sequentially so application semantics remain identical.

This does not make Rack itself fiber-multiplex unrelated requests. Puma still owns cross-request scheduling with its adaptive 30–50 thread pool. Async is used **inside a selected controller request** to overlap independent socket waits on fibers sharing that one Puma worker thread.

Tuning:

```sh
RAILS_ASYNC_IO=1
RAILS_ASYNC_FANOUT_LIMIT=4   # 1..8
```

CI includes a real socket smoke test where two HTTP responses are withheld until both connections have arrived. The two `Net::HTTP` calls must therefore overlap; CI also asserts both client fibers execute on one Ruby thread with one Fiber scheduler.


### Ruby runtime capability

The async path is capability-gated, not engine-name-gated. If `Fiber.scheduler` exists, Rails can use the bounded Async fan-out. If it does not, the same `parallel_requests` call executes the operations sequentially.

The current CI TruffleRuby 34.0.1 image reports Ruby 3.4.9 compatibility but does not expose `Fiber.scheduler`, so its Rails mode currently uses the sequential intra-request fallback. It still uses the same adaptive Puma request pool for cross-request concurrency. No hidden fallback thread pool is created, so the Rails process does not silently exceed the configured request-thread budget.
