#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/scripts/common.sh"

for tool in python3 ansible-vault ansible-galaxy ssh-keygen flock; do
  need "$tool"
done

mkdir -p "$ROOT/.local" "$ROOT/ansible/group_vars/all"
chmod 700 "$ROOT/.local"

acquire_lock

private_key="$ROOT/.local/id_ed25519"
public_key="$ROOT/.local/id_ed25519.pub"
vault_password="$ROOT/.local/vault.pass"
vault_file="$ROOT/ansible/group_vars/all/vault.yml"

if [[ -e "$private_key" || -e "$public_key" ]]; then
  if [[ ! -s "$private_key" || ! -s "$public_key" ]]; then
    echo "Incomplete SSH key pair. Restore the original key files." >&2
    exit 1
  fi
else
  ssh-keygen -q \
    -t ed25519 \
    -N '' \
    -C aws-container-project \
    -f "$private_key"
fi

chmod 600 "$private_key"
chmod 644 "$public_key"

if [[ ! -e "$vault_password" ]]; then
  if [[ -e "$vault_file" ]]; then
    echo "Vault exists but its password is missing. Restore the original vault.pass." >&2
    exit 1
  fi

  python3 -c 'import secrets; print(secrets.token_urlsafe(48))' \
    > "$vault_password"
fi

if [[ ! -s "$vault_password" ]]; then
  echo "Vault password file is empty. Restore it before continuing." >&2
  exit 1
fi

chmod 600 "$vault_password"

if [[ ! -e "$vault_file" ]]; then
  python3 -c 'import secrets; print("vault_db_password: " + secrets.token_hex(32))' |
    ansible-vault encrypt \
      --vault-password-file "$vault_password" \
      --output "$vault_file"
fi

chmod 600 "$vault_file"

ansible-vault view \
  --vault-password-file "$vault_password" \
  "$vault_file" > /dev/null

if [[ ! -e "$ROOT/terraform/terraform.tfvars" ]]; then
  cp "$ROOT/terraform/terraform.tfvars.example" \
    "$ROOT/terraform/terraform.tfvars"
fi

ansible-galaxy collection install \
  -r "$ROOT/ansible/requirements.yml"

echo "Setup completed."
echo "Review terraform/terraform.tfvars before deployment."
