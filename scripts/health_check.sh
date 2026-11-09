#!/usr/bin/env bash
set -Eeuo pipefail

url="${1:?Usage: health_check.sh http://WEB_IP}"

if ! command -v curl >/dev/null 2>&1; then
  echo "Missing required command: curl" >&2
  exit 1
fi

for attempt in {1..30}; do
  code="$(
    curl \
      --silent \
      --output /dev/null \
      --write-out '%{http_code}' \
      --connect-timeout 3 \
      --max-time 8 \
      "${url%/}/health" || true
  )"

  if [[ "$code" == "200" ]]; then
    echo "Health check passed: /health returned HTTP 200."
    exit 0
  fi

  printf 'Waiting for application: attempt %s/30, HTTP %s\n' \
    "$attempt" "$code"

  if (( attempt < 30 )); then
    sleep 4
  fi
done

echo "Health check failed: /health did not return HTTP 200." >&2
exit 1
