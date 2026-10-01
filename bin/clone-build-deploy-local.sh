#!/usr/bin/env bash
set -euo pipefail

ROOT="${ORES_DEMO_HOME:-$PWD/ores-ror-local}"
COMPOSE_DIR="$ROOT/ores-compose"
APP_DIR="$ROOT/ores-ror.rb"
APP_REF="${APP_REF:-harden/route-contract-audit}"
CHECK_ONLY="${CHECK_ONLY:-false}"

for command_name in git cargo ruby bundle truffleruby; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "required command not found: $command_name" >&2
    exit 1
  }
done

mkdir -p "$ROOT"

if [[ ! -d "$COMPOSE_DIR/.git" ]]; then
  git clone https://github.com/ORESoftware/ores-compose.git "$COMPOSE_DIR"
else
  git -C "$COMPOSE_DIR" fetch --prune origin
  git -C "$COMPOSE_DIR" checkout main
  git -C "$COMPOSE_DIR" pull --ff-only origin main
fi

cargo build --release --locked --manifest-path "$COMPOSE_DIR/Cargo.toml"
COMPOSE_BIN="$COMPOSE_DIR/target/release/ores-compose"

if [[ ! -d "$APP_DIR/.git" ]]; then
  git clone https://github.com/ores-ror-to-lambdas-demo/ores-ror.rb.git "$APP_DIR"
else
  git -C "$APP_DIR" fetch --prune origin
fi

git -C "$APP_DIR" checkout "$APP_REF" 2>/dev/null || git -C "$APP_DIR" checkout -B "$APP_REF" "origin/$APP_REF"
git -C "$APP_DIR" pull --ff-only origin "$APP_REF" || true

cd "$APP_DIR"

./bin/local-install-mri.sh
./bin/local-install-truffleruby.sh

BUNDLE_PATH="$APP_DIR/vendor/bundle-mri" bundle exec ruby bin/verify-routes
BUNDLE_PATH="$APP_DIR/vendor/bundle-truffleruby" \
  ORES_BUILD_TARGET=lambda \
  ORES_LAMBDA_HANDLER_GRANULARITY=route \
  truffleruby -S bundle exec truffleruby bin/build-runtime

"$COMPOSE_BIN" check .ores-compose.yaml
"$COMPOSE_BIN" plan .ores-compose.yaml

if [[ "$CHECK_ONLY" == "true" ]]; then
  echo "clone/build/compose validation complete: $APP_DIR"
  exit 0
fi

cat <<'MSG'
Starting both runtimes under ores-compose:
  Rails/Puma:   http://127.0.0.1:3100/healthz
  Graal host:   http://127.0.0.1:3200/healthz
  Graal status: http://127.0.0.1:3200/__ores/cluster

Ctrl-C stops the attached ores-compose supervisor.
MSG

export ORES_COMPOSE_SKIP_ZED_PKG=true
export ORES_COMPOSE_SKIP_RPC_GEN=true
exec "$COMPOSE_BIN" up .ores-compose.yaml
