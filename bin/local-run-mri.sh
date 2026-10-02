#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export BUNDLE_PATH="$PWD/vendor/bundle-mri"
export DATA_API_URL="${DATA_API_URL:-http://127.0.0.1:8787/v1}"
export RAILS_ENV="${RAILS_ENV:-development}"
export PORT="${PORT:-3100}"

# Invoke Puma directly so Puma 8 concurrency features in config/puma.rb are
# guaranteed to be active; rails server does not expose every Puma feature.
exec bundle exec puma -C config/puma.rb config.ru
