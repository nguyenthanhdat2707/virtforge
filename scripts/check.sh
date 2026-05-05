#!/usr/bin/env bash
set -euo pipefail

terraform fmt -check -recursive
terraform -chdir=terraform/envs/nonprod/dev init -backend=false -input=false
terraform -chdir=terraform/envs/nonprod/dev validate -no-color
terraform -chdir=terraform/modules/vm_stack init -backend=false -input=false
terraform -chdir=terraform/modules/vm_stack validate -no-color

if command -v ansible-playbook >/dev/null 2>&1; then
  ansible-playbook --syntax-check -i ansible/inventory/hosts.ini.example ansible/playbook/ping.yml
  ansible-playbook --syntax-check -i localhost, ansible/playbook/prepare-hugepages.yml
else
  echo "ansible-playbook not found; skipping Ansible syntax check"
fi
