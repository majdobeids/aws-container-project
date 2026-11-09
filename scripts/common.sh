#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

export ANSIBLE_CONFIG="$ROOT/ansible/ansible.cfg"
export ANSIBLE_VAULT_PASSWORD_FILE="$ROOT/.local/vault.pass"
export ANSIBLE_NOCOLOR=1

umask 077

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

require_setup() {
  local file

  for file in \
    .local/id_ed25519 \
    .local/id_ed25519.pub \
    .local/vault.pass \
    ansible/group_vars/all/vault.yml \
    terraform/terraform.tfvars
  do
    if [[ ! -s "$ROOT/$file" ]]; then
      printf 'Missing or empty setup file: %s\n' "$file" >&2
      exit 1
    fi
  done
}

acquire_lock() {
  mkdir -p "$ROOT/.local"

  exec 9>"$ROOT/.local/operation.lock"

  if ! flock -n 9; then
    echo "Another project operation is already running." >&2
    exit 1
  fi
}

run_ansible() {
  (
    cd "$ROOT/ansible"
    ansible-playbook -i inventory.json site.yml "$@"
  )
}
