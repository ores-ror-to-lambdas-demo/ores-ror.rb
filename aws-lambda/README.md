# TruffleRuby on AWS Lambda

This target is generated from the same repository as the ordinary Rails application, but **does not boot Rails**.

Build mode is selected only with environment variables:

```sh
ORES_BUILD_TARGET=lambda ORES_LAMBDA_HANDLER_GRANULARITY=route ruby bin/build-runtime
```

The default `route` mode generates one `handler.rb` for every route. Codegen also generates grouped handlers such as `groups/orders/handler.rb`; selecting `ORES_LAMBDA_HANDLER_GRANULARITY=group` makes the generated entrypoint dispatch through those group switches instead.

`aws-lambda/adapter.rb` only adapts API Gateway/Lambda events to the generated lambda entrypoint. It is deliberately not named `handler.rb`: the actual application handlers are the generated per-route/group `handler.rb` files. The adapter never requires `config/environment` or calls `Rails.application`. `runtime.rb` implements AWS Lambda's custom Runtime API loop, and `bootstrap` starts it under TruffleRuby.

The Lambda image installs the Gemfile with `BUNDLE_WITHOUT=rails`, runs codegen during the image build, and therefore proves that the lambda execution path does not depend on the Rails runtime.

Generated artifacts are intentionally not version-controlled.
