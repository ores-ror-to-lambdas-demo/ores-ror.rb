# TruffleRuby on AWS Lambda

This target uses the same Rails application as Puma and the Graal worker cluster. There are no Lambda-specific controllers, routes, services, models, or business rules.

`handler.rb` translates API Gateway HTTP API v2 / Lambda Function URL events (plus API Gateway v1 compatibility) into the shared `OresRuntime::RackDispatch` request shape. `runtime.rb` implements AWS Lambda's custom Runtime API loop. `bootstrap` is the custom-runtime entry point. The container uses the official GraalVM Community TruffleRuby standalone image, so Lambda executes TruffleRuby native standalone rather than MRI.

The runtime is warm: Rails boots once per Lambda execution environment and subsequent invocations reuse the loaded application and HTTP pools. Standard Lambda execution environments invoke one request at a time; scaling comes from Lambda creating additional environments. The self-hosted Graal target instead keeps multiple Rails/TruffleRuby workers inside each warm cell.
