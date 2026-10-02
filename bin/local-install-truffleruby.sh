#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v truffleruby >/dev/null 2>&1 || {
  echo 'truffleruby is required (recommended: truffleruby+graalvm-25.0.0).' >&2
  exit 1
}
export BUNDLE_PATH="$PWD/vendor/bundle-truffleruby"
exec truffleruby -S bundle install --jobs "${BUNDLE_JOBS:-4}" --retry 3
