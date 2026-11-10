# Automated Deployment of a Containerized App on AWS

A hands-on project combining Linux, Bash, Python, Git/GitHub, Docker, Ansible, Terraform, and AWS.

The application is deployed with one command:

    ./deploy.sh

All Terraform-managed project resources are removed with:

    ./destroy.sh

This project does not include CI/CD workflows.

## Architecture

![Architecture](docs/architecture.svg)

- Terraform provisions a VPC, public subnet, internet gateway, and routing.
- Two Ubuntu 24.04 EC2 instances run the web and database services.
- Separate security groups control access to each server.
- The web server runs Nginx and Flask/Gunicorn using Docker Compose.
- The database server runs PostgreSQL with a persistent Docker volume.
- Flask connects to PostgreSQL through the database server's private IP.
- Python generates the Ansible inventory from Terraform outputs.
- Ansible configures both servers using roles and Vault-encrypted variables.
- A cron job runs pg_dump and uploads compressed backups to a private S3 bucket.
- The database server uses an IAM role to upload backups without stored AWS access keys.

Both EC2 instances use public IPv4 addresses for administrative SSH access and outbound package downloads. PostgreSQL is published only on the database server's private IP, and its security group allows port 5432 only from the web security group.

This is a learning environment, not a highly available production architecture.

## Project Structure

| Path | Purpose |
|---|---|
| terraform/ | AWS resources, variables, and outputs |
| ansible/roles/ | Linux, Docker, database, web, and backup configuration |
| ansible/group_vars/all/ | Shared variables and the locally generated Vault file |
| app/ | Flask application, Dockerfile, and Python dependencies |
| scripts/gen_inventory.py | Generates inventory from Terraform JSON outputs |
| scripts/common.sh | Shared Bash functions and environment configuration |
| scripts/health_check.sh | Checks the application's HTTP health endpoint |
| scripts/check_idempotence.sh | Verifies the second Ansible run reports no changes |
| setup.sh | Prepares local keys, Vault, and configuration |
| deploy.sh | Provisions infrastructure and deploys the application |
| destroy.sh | Removes Terraform-managed resources |
| docs/architecture.svg | Architecture diagram |
| .local/ | Private local files excluded from Git |

## Requirements

Run the project from Linux or Ubuntu inside WSL.

Required tools:

- Python 3.14 with virtual environment support.
- Git, Bash, curl, OpenSSH, and flock.
- Terraform >= 1.6 and < 2.0.
- AWS CLI v2 with valid authentication.
- An AWS identity with the required EC2, VPC, S3, IAM, iam:PassRole, and SSM read permissions.

Ansible dependencies are defined in requirements.txt and ansible/requirements.yml.

Local Docker is optional for container testing. During deployment, Ansible installs Docker on the EC2 instances and builds the application image on the web server.

## Cost Considerations

Choosing t3.micro does not automatically make the deployment free.

Check your account's AWS Free Tier eligibility, remaining credits, and selected region before deployment.

The project uses:

- Two EC2 instances.
- Two public IPv4 addresses.
- Two 8 GiB EBS volumes, totaling 16 GiB.
- S3 storage and requests.
- Applicable data transfer.

No NAT Gateway or Load Balancer is provisioned.

Destroy the resources after each learning session.

## Initial Setup

From the repository root:

    python3 -m venv .venv
    source .venv/bin/activate
    python -m pip install -r requirements.txt
    ./setup.sh

The setup script creates missing local files while preserving existing ones:

- .local/id_ed25519
- .local/id_ed25519.pub
- .local/vault.pass
- ansible/group_vars/all/vault.yml
- terraform/terraform.tfvars

It also installs the required Ansible collection.

Keep the SSH keys, Vault password, and encrypted Vault file protected. Do not regenerate them while existing resources depend on them.

## AWS Authentication

List the AWS profiles available on your machine:

    aws configure list-profiles

Select an actual profile from that list.

The deployment environment used a profile named my-project:

    export AWS_PROFILE=my-project

Replace that name if your profile is different. Do not use a placeholder profile name literally.

Verify authentication:

    aws sts get-caller-identity

If your profile uses SSO, sign in to that profile before deployment.

## Terraform Configuration

Edit terraform/terraform.tfvars:

| Variable | Description |
|---|---|
| aws_region | AWS region for the deployment |
| project | Resource naming prefix and project tag |
| admin_cidr | Your current public IPv4 address followed by /32 |
| http_cidr | IPv4 range allowed to access HTTP |
| instance_type | t3.micro or t2.micro, subject to availability and account eligibility |

Update admin_cidr whenever your public IP or VPN connection changes.

The SSH public key path defaults to ../.local/id_ed25519.pub, relative to the Terraform directory.

Commit .terraform.lock.hcl to preserve provider selections. Do not commit local state, private keys, or terraform.tfvars.

## One-Command Deployment

Activate the virtual environment and the correct AWS profile, then run:

    ./deploy.sh

The script:

1. Checks required commands and local setup files.
2. Acquires a lock to prevent overlapping project operations.
3. Verifies AWS authentication.
4. Runs Terraform init, validate, plan, and apply.
5. Generates the Ansible inventory from Terraform outputs.
6. Configures Linux and Docker on both servers.
7. Deploys PostgreSQL and configures backups.
8. Builds and starts Flask and Nginx.
9. Checks /health and prints the application URL.

The saved Terraform plan is applied without an additional interactive confirmation.

If deployment fails after provisioning starts, resources may remain. Fix the error and rerun the script, or use destroy.sh to clean up.

## Application Health

Read the application URL and check its health:

    URL=$(terraform -chdir=terraform output -raw app_url)
    ./scripts/health_check.sh "$URL"
    curl -i "$URL/health"

The /health endpoint executes SELECT 1 against PostgreSQL.

- HTTP 200 means the database connection and query succeeded.
- HTTP 503 means the database connection is not ready or failed.

The home page can respond successfully even when the database is unavailable.

## Ansible Idempotence

Immediately after a successful deployment, run:

    ./scripts/check_idempotence.sh

The script performs a real second Ansible run and verifies both hosts report:

    changed=0
    unreachable=0
    failed=0

It saves the output to .local/idempotence.log.

This test does not use Ansible check mode.

File changes, external modifications, removed containers, or expired apt cache validity can cause legitimate changes on later runs.

## Database Backups

The backup script is installed on the database server at:

    /usr/local/sbin/backup-postgres.sh

It:

1. Acquires a lock to prevent overlapping backups.
2. Runs pg_dump in custom format inside the PostgreSQL container.
3. Generates a SHA256 checksum.
4. Packages the dump and checksum into a tar.gz archive.
5. Uploads the archive to the postgres/ prefix in S3.
6. Removes temporary files, including after failures.

AWS CLI v2 is installed from the official AWS distribution when missing.

Uploads use the EC2 IAM role. The upload policy does not grant backup listing, download, or deletion permissions.

The cron job runs daily at 02:00 in the server's timezone. The tested server used Etc/UTC, so this corresponds to 05:00 in Baghdad.

S3 lifecycle rules make backups eligible for expiration after seven days. Lifecycle deletion is not immediate.

### Run a Manual Backup

After deployment:

    DB=$(terraform -chdir=terraform output -raw db_public_ip)

    ssh -i .local/id_ed25519 \
      -o UserKnownHostsFile=.local/known_hosts \
      "ubuntu@$DB" \
      'sudo /usr/local/sbin/backup-postgres.sh'

### List Backups

Use an operator identity with the required S3 listing permissions:

    BUCKET=$(terraform -chdir=terraform output -raw backup_bucket)
    REGION=$(terraform -chdir=terraform output -raw aws_region)

    aws s3 ls "s3://$BUCKET/postgres/" --region "$REGION"

### Verify a Downloaded Backup

After downloading and extracting an archive:

    cd .local/restore
    sha256sum -c SHA256SUMS

Expected result:

    database.dump: OK

Use pg_restore to test restoration into a separate database.

The dump contains the application database, not PostgreSQL global roles. A checksum verifies file integrity; it does not by itself prove successful restoration.

## Secrets and Security Notes

- Database passwords are generated locally and stored in an Ansible Vault file.
- The Vault password and private SSH key remain on the control machine.
- Sensitive local configuration and generated files are excluded from Git.
- Secret-writing Ansible tasks use no_log.
- Runtime secret files have restricted permissions, but root can read them.
- Docker Compose secrets in this project are mounted files, not an encrypted runtime secret store.
- The SSH private key has no passphrase to support automated lab deployment; protect it carefully.
- SSH uses trust on first use for host keys and rejects subsequent unexpected changes.
- PostgreSQL accepts application traffic only from the web security group.
- Changing the Vault password variable does not automatically rotate credentials in an existing PostgreSQL volume.
- Persistent volumes survive container replacement but not deletion of their backing EC2 disk.
- Existing EC2 instances are not automatically replaced when a newer AMI becomes available.
- Terraform state is local. Shared administration requires an appropriate shared backend and locking strategy.

## Cleanup

Run:

    ./destroy.sh

Then verify:

    terraform -chdir=terraform state list

The resource list should be empty after successful destruction.

Also verify cleanup in the AWS Console using the correct account and region.

Warning: destruction removes the EC2 disks, S3 bucket, and all backups stored in that bucket. Download any backup you want to retain first.

Keep the original Terraform state and configuration until cleanup is confirmed. Resources created outside this Terraform project are not removed by the script.

## Observed Validation Results

The following results were observed during the project execution:

| Check | Result |
|---|---|
| Terraform validation | Passed |
| Infrastructure plan | 17 resources to create |
| Generated inventory | web and db groups recognized; file permissions 0600 |
| Ansible syntax checks | Passed |
| Rendered Compose configuration checks | Passed |
| Local Flask container | Started successfully as UID/GID 10001 |
| One-command AWS deployment | Passed |
| Application health on AWS | HTTP 200 |
| Second Ansible run | Both hosts reported changed=0, unreachable=0, failed=0 |
| Manual database backup | Uploaded successfully to S3 |
| Downloaded backup checksum | database.dump: OK |
| Local PostgreSQL test query | SELECT 1 returned one row |
| Cron configuration | Active service; daily job at 02:00 UTC |
| Cleanup | 17 resources destroyed; Terraform state empty |

The scheduled cron execution was not observed at its scheduled time; the backup script was tested manually.

The application URL is temporary and becomes unavailable after cleanup.

## GitHub Workflow

Implementation branches:

- main
- feature/terraform
- feature/ansible-compose
- feature/deploy-scripts

Merged implementation pull requests:

- PR #1: Terraform infrastructure.
- PR #2: Application and Ansible roles.
- PR #3: Deployment scripts, documentation, and AWS CLI installation fix.

The repository contains no CI/CD workflows.

End 
- Majd Obeid
