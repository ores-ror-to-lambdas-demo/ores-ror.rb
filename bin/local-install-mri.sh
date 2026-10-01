#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export BUNDLE_PATH="$PWD/vendor/bundle-mri"
exec bundle install --jobs "${BUNDLE_JOBS:-4}" --retry 3
