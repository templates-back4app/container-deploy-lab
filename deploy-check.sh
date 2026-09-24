#!/usr/bin/env bash
# Stack: bash | Verifies a deployed container-deploy-lab end to end: health → root.
# Usage: ./deploy-check.sh https://your-app.b4a.run
set -euo pipefail
BASE="${1:?usage: deploy-check.sh <base-url>}"

echo "1/2 health"; curl -fsS --max-time 10 "$BASE/healthz" | grep -q '"ok":true'
echo "2/2 root";   BODY=$(curl -fsS --max-time 10 "$BASE/")
echo "    $BODY"
echo "$BODY" | grep -q 'container-deploy-lab' || { echo "root did not answer with the app banner"; exit 1; }
echo "OK — $BASE is serving container-deploy-lab"
