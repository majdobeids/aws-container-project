#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

for tool in ansible-playbook python3 flock tee; do
  need "$tool"
done

require_setup

if [[ ! -s "$ROOT/ansible/inventory.json" ]]; then
  echo "Missing inventory. Run ./deploy.sh successfully first." >&2
  exit 1
fi

acquire_lock

log="$ROOT/.local/idempotence.log"

echo "Running Ansible again to verify idempotence..."
run_ansible | tee "$log"

python3 - "$log" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()

pattern = (
    r"^(web1|db1)\s+:\s+"
    r"ok=(\d+)\s+"
    r"changed=(\d+)\s+"
    r"unreachable=(\d+)\s+"
    r"failed=(\d+)"
)

results = re.findall(pattern, text, re.MULTILINE)

if len(results) != 2 or {row[0] for row in results} != {"web1", "db1"}:
    raise SystemExit("FAIL: expected one recap for each server.")

for host, ok, changed, unreachable, failed in results:
    if any(int(value) != 0 for value in (changed, unreachable, failed)):
        raise SystemExit(
            f"FAIL: {host}: changed={changed}, "
            f"unreachable={unreachable}, failed={failed}"
        )

print("PASS: both servers have changed=0, unreachable=0, failed=0.")
PY
