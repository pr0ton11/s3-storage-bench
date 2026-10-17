#!/usr/bin/env bash
# Runs the benchmark from Exoscale zones, unattended. One instance per zone, deleted when its run has finished.
#
#   exoscale/run.sh <zone>...            for example: exoscale/run.sh ch-gva-2 de-fra-1 at-vie-1
#
# Reads .env in the repository root. RESULTS_* must be set, because the instance is deleted after the run.
# The instance builds the image from the commit that is checked out here, so push it first.
#   INSTANCE_TYPE   default standard.medium
#   SSH_KEY         name of an Exoscale SSH key to install, for a look at /opt/bench/run.log
#   KEEP=1          keep the instances after the run
set -euo pipefail
cd "$(dirname "$0")/.."

zones=("$@")
[ ${#zones[@]} -gt 0 ] || { echo "usage: $0 <zone>..." >&2; exit 2; }
grep -q '^RESULTS_ENDPOINT=.' .env || { echo "RESULTS_ENDPOINT is not set in .env, and the instance is deleted after the run" >&2; exit 2; }

ref=$(git rev-parse HEAD)
git fetch -q origin
git branch -r --contains "$ref" | grep -q . || { echo "commit $ref is not pushed; the instance clones from GitHub" >&2; exit 2; }

type=${INSTANCE_TYPE:-standard.medium}
stamp=$(date -u +%Y%m%d-%H%M)
env_b64=$(base64 < .env | tr -d '\n')
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

for zone in "${zones[@]}"; do
  name="bench-$zone-$stamp"
  sed -e "s|__ENV_B64__|$env_b64|" -e "s|__REF__|$ref|" -e "s|__CLIENT__|exo-$zone|" exoscale/cloud-init.yaml > "$tmp/$zone.yaml"
  exo compute instance create "$name" --zone "$zone" --instance-type "$type" --template "Linux Ubuntu 24.04 LTS 64-bit" \
    --disk-size 20 --cloud-init "$tmp/$zone.yaml" ${SSH_KEY:+--ssh-key "$SSH_KEY"} -Q
  echo "$zone: started $name"
done

for zone in "${zones[@]}"; do
  name="bench-$zone-$stamp"
  until [ "$(exo compute instance show "$name" --zone "$zone" -O json | jq -r .state)" = stopped ]; do sleep 60; done
  echo "$zone: finished"
  [ "${KEEP:-}" = 1 ] || exo compute instance delete "$name" --zone "$zone" -f -Q
done
