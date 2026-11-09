#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/scripts/common.sh"

for tool in terraform aws flock; do
  need "$tool"
done

if [[ ! -s "$ROOT/terraform/terraform.tfvars" ]]; then
  echo "Missing terraform.tfvars. Restore the original configuration." >&2
  exit 1
fi

if [[ ! -s "$ROOT/.local/id_ed25519.pub" ]]; then
  echo "Missing SSH public key. Restore the original public key file." >&2
  exit 1
fi

if [[ ! -f "$ROOT/terraform/terraform.tfstate" ]]; then
  echo "No local Terraform state found. If resources exist, restore their original state before cleanup." >&2
  exit 1
fi

acquire_lock

trap 'echo "Cleanup failed. Some AWS resources may remain. Inspect the error and rerun." >&2' ERR

echo "Deleting this Terraform stack, EC2 volumes, S3 bucket and ALL its backups."

aws sts get-caller-identity >/dev/null

terraform -chdir="$ROOT/terraform" init -input=false

terraform -chdir="$ROOT/terraform" plan \
  -destroy \
  -input=false \
  -out="$ROOT/.local/destroy.tfplan"

terraform -chdir="$ROOT/terraform" apply \
  -input=false \
  "$ROOT/.local/destroy.tfplan"

rm -f \
  "$ROOT/.local/destroy.tfplan" \
  "$ROOT/.local/deploy.tfplan" \
  "$ROOT/ansible/inventory.json" \
  "$ROOT/.local/known_hosts"

echo "Terraform destruction completed."
echo "Verify the AWS console. Keep local state and keys until cleanup is confirmed."
