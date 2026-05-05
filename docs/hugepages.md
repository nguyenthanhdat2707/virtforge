# Hugepages

Hugepages are optional per VM. Terraform declares which VM should use hugepages; Ansible prepares the host to reserve enough pages before `terraform apply`.

## VM Configuration

In `terraform.tfvars`, enable hugepages only for VMs that benefit from it:

```hcl
vms = {
  gitlab = {
    ram_mib = 8192

    hugepages = {
      enabled = true
    }
  }

  gitlabrunner = {
    ram_mib = 8192

    hugepages = {
      enabled  = true
      size_mib = 2
    }
  }
}
```

If `size_mib` is omitted, Terraform defaults to 2 MiB hugepages.

## Host Reservation Plan

Generate a host reservation plan from your local `terraform.tfvars`:

```bash
bash scripts/hugepages-plan.sh \
  --tfvars terraform/envs/nonprod/dev/terraform.tfvars \
  --write ansible/inventory/hugepages.auto.json
```

The script uses `terraform console` to read `tfvars`, then calculates:

- VMs with `hugepages.enabled = true`.
- Total VM RAM that must be backed by hugepages.
- Hugepage count based on `ram_mib / size_mib`.
- Percentage of host RAM that would be reserved.

## Prepare Host

Apply the generated plan locally:

```bash
ansible-playbook \
  -i localhost, \
  ansible/playbook/prepare-hugepages.yml \
  -e @ansible/inventory/hugepages.auto.json \
  --ask-become-pass
```

Then run Terraform:

```bash
terraform -chdir=terraform/envs/nonprod/dev apply
```

## Current Boundary

The Ansible role currently manages 2 MiB hugepages through `vm.nr_hugepages`. Terraform can express other page sizes, but host preparation for 1 GiB pages is intentionally not automated yet because it usually needs boot-time kernel configuration and stricter hardware checks.
