#!/usr/bin/env bash
# Runs the benchmark from Exoscale zones, one zone after the other. Each instance is deleted when its run has finished.
#
#   exoscale/run.sh <zone>...            for example: exoscale/run.sh ch-gva-2 de-fra-1 at-vie-1
#
# Reads .env in the repository root. RESULTS_* must be set, because the instance is deleted after the run.
# When RESULTS_ENDPOINT is Exoscale object storage (https://sos-<zone>.exo.io), the script creates the bucket
# when it is missing and downloads the results of this run to results/<stamp>/ at the end.
# The instance pulls the image of the commit that is checked out here, or builds it from GitHub when the image is
# not published yet, so push it first.
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
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Each run gets its own prefix in the results bucket, so the download at the end fetches only this run.
setting() { sed -n "s/^$1=//p" .env | tail -1; }
prefix="$(setting RESULTS_PREFIX)"
prefix="${prefix:-results}/$stamp"
{ grep -v '^RESULTS_PREFIX=' .env; echo "RESULTS_PREFIX=$prefix"; } > "$tmp/env"
env_b64=$(base64 < "$tmp/env" | tr -d '\n')

download=
if [[ "$(setting RESULTS_ENDPOINT)" =~ ^https://sos-([a-z0-9-]+)\.exo\.io/?$ ]]; then
  bucket=$(setting RESULTS_BUCKET)
  exo storage ls "sos://$bucket" >/dev/null 2>&1 || exo storage mb "sos://$bucket" --zone "${BASH_REMATCH[1]}" -Q
  download="sos://$bucket/$prefix/"
fi

# One zone at a time: the endpoint under test is shared, and two runners at once would measure each other.
for zone in "${zones[@]}"; do
  name="bench-$zone-$stamp"
  sed -e "s|__ENV_B64__|$env_b64|" -e "s|__REF__|$ref|" -e "s|__CLIENT__|exo-$zone|" exoscale/cloud-init.yaml > "$tmp/$zone.yaml"
  exo compute instance create "$name" --zone "$zone" --instance-type "$type" --template "Linux Ubuntu 24.04 LTS 64-bit" \
    --disk-size 20 --cloud-init "$tmp/$zone.yaml" ${SSH_KEY:+--ssh-key "$SSH_KEY"} -Q
  echo "[$(date -u +%H:%M:%S)] $zone: started $name"
  until [ "$(exo compute instance show "$name" --zone "$zone" -O json | jq -r .state)" = stopped ]; do sleep 60; done
  echo "[$(date -u +%H:%M:%S)] $zone: finished"
  [ "${KEEP:-}" = 1 ] || exo compute instance delete "$name" --zone "$zone" -f -Q
done

if [ -n "$download" ]; then
  mkdir -p "results/$stamp"
  exo storage download -r "$download" "results/$stamp/" -Q
  echo "results in results/$stamp/"
fi
