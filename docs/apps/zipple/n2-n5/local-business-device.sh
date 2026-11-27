#!/usr/bin/env bash
set -euo pipefail
adb reverse tcp:4443 tcp:4443
set -a
source "$RUNNER_TEMP/zipple-business.env"
set +a
export ZIPPLE_TLS_KEY="$RUNNER_TEMP/zipple-ci.key" ZIPPLE_TLS_CERT="$RUNNER_TEMP/zipple-ci.crt"
bash docs/apps/zipple/n2-n5/local-edge-ready.sh
node --test docs/apps/zipple/n2-n5/local-business-device.test.mjs
