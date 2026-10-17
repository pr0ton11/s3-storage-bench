#!/bin/sh
# Runs storage-bench against the configured targets, writes the report, and uploads the results when a results
# bucket is configured. Environment:
#   CLIENT     name of this machine in the results, default: the hostname
#   PROFILE    smoke (a short connectivity check, not reported) or full, default: smoke
#   PASSES     how many full passes to run, default: 1
#   PROVIDERS  comma-separated target ids to run, default: every configured target
#   TARGET_*   the endpoints to measure, see src/providers.ts
#   RESULTS_*  where to upload the results, see src/upload.ts
set -eu
CLIENT=${CLIENT:-$(hostname)}
PROFILE=${PROFILE:-smoke}
PASSES=${PASSES:-1}
OUT=${OUT:-/results}
mkdir -p "$OUT/raw"

pass=1
while [ "$pass" -le "$PASSES" ]; do
  echo "[$(date -u +%H:%M:%S)] pass $pass of $PASSES, profile $PROFILE, client $CLIENT" >&2
  # shellcheck disable=SC2086
  node src/bench.ts --client "$CLIENT" --profile "$PROFILE" --out "$OUT/raw" --code-version "storage-bench@$UPSTREAM_COMMIT" ${PROVIDERS:+--providers "$PROVIDERS"}
  pass=$((pass + 1))
done

node src/report.ts --in "$OUT/raw" --out "$OUT" --exclusions "$OUT/exclusions.json"

if [ -n "${RESULTS_ENDPOINT:-}" ]; then
  node src/upload.ts --dir "$OUT" --client "$CLIENT"
fi
