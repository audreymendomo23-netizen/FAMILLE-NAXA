#!/usr/bin/env bash
set -euo pipefail
adb reverse tcp:4443 tcp:4443
set -a
source "$RUNNER_TEMP/zipple-local.env"
set +a
export ZIPPLE_TLS_KEY="$RUNNER_TEMP/zipple-ci.key" ZIPPLE_TLS_CERT="$RUNNER_TEMP/zipple-ci.crt" ZIPPLE_ANDROID_LIVE=1
node --test docs/apps/zipple/n1/backend/local-live.test.mjs
