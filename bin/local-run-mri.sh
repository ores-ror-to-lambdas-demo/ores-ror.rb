#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export BUNDLE_PATH="$PWD/vendor/bundle-mri"
export DATA_API_URL="${DATA_API_URL:-http://127.0.0.1:8787/v1}"
export RAILS_ENV="${RAILS_ENV:-development}"
exec bundle exec rails server -b 127.0.0.1 -p "${PORT:-3100}"
