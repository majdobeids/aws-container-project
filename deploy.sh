#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/scripts/common.sh"

for tool in terraform aws python3 ansible-playbook curl flock; do
  need "$tool"
done

require_setup
acquire_lock

trap 'echo "Deployment failed. AWS resources may exist. Fix the error and rerun, or use ./destroy.sh." >&2' ERR

echo "Checking AWS authentication..."
aws sts get-caller-identity >/dev/null

echo "Initializing Terraform..."
terraform -chdir="$ROOT/terraform" init -input=false

echo "Validating Terraform..."
terraform -chdir="$ROOT/terraform" validate

echo "Planning AWS resources..."
terraform -chdir="$ROOT/terraform" plan \
  -input=false \
  -out="$ROOT/.local/deploy.tfplan"

echo "Applying the saved Terraform plan..."
terraform -chdir="$ROOT/terraform" apply \
  -input=false \
  "$ROOT/.local/deploy.tfplan"

rm -f "$ROOT/.local/deploy.tfplan"

echo "Generating the Ansible inventory..."
terraform -chdir="$ROOT/terraform" output -json |
  python3 "$ROOT/scripts/gen_inventory.py" \
    --key "$ROOT/.local/id_ed25519" \
    --known-hosts "$ROOT/.local/known_hosts" \
    --output "$ROOT/ansible/inventory.json"

echo "Configuring servers and deploying containers..."
run_ansible

url="$(terraform -chdir="$ROOT/terraform" output -raw app_url)"

echo "Checking application health..."
"$ROOT/scripts/health_check.sh" "$url"

printf 'Deployment completed: %s\n' "$url"
