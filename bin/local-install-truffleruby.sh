#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v truffleruby >/dev/null 2>&1 || {
  echo 'truffleruby+graalvm is required.' >&2
  exit 1
}
export BUNDLE_PATH="$PWD/vendor/bundle-truffleruby"
export BUNDLE_WITHOUT="rails"
exec truffleruby -S bundle install --jobs "${BUNDLE_JOBS:-4}" --retry 3
