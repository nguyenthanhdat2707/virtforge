#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tf_dir="${repo_root}/terraform/envs/nonprod/dev"
tfvars="${tf_dir}/terraform.tfvars"
json_only=false
write_file=""
max_host_ram_percent=75

usage() {
  cat <<'EOF'
Usage:
  scripts/hugepages-plan.sh [--tfvars PATH] [--write PATH] [--json]

Options:
  --tfvars PATH   Terraform tfvars file to inspect. Defaults to dev terraform.tfvars,
                  then falls back to terraform.tfvars.example when tfvars is absent.
  --write PATH    Write the generated Ansible extra-vars JSON to PATH.
  --json          Print only JSON.
  -h, --help      Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --tfvars)
      tfvars="$2"
      shift 2
      ;;
    --write)
      write_file="$2"
      shift 2
      ;;
    --json)
      json_only=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ ! -f "$tfvars" ]; then
  tfvars="${tf_dir}/terraform.tfvars.example"
fi

case "$tfvars" in
  /*) ;;
  *) tfvars="$(pwd)/$tfvars" ;;
esac

for bin in terraform jq awk; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Required command not found: $bin" >&2
    exit 127
  fi
done

host_mem_mib="$(awk '/MemTotal:/ { printf "%d\n", $2 / 1024 }' /proc/meminfo)"
tmp_state="$(mktemp "${TMPDIR:-/tmp}/jdi-tf-console-state.XXXXXX")"
trap 'rm -f "$tmp_state" "$tmp_state.lock.info"' EXIT

expression='jsonencode({ for name, vm in var.vms : name => { ram_mib = vm.ram_mib, hugepages = vm.hugepages } })'

vms_json="$(
  printf '%s\n' "$expression" |
    terraform -chdir="$tf_dir" console -state="$tmp_state" -var-file="$tfvars" |
    jq -r .
)"

plan_json="$(
  jq -n \
    --argjson vms "$vms_json" \
    --arg host_mem_mib "$host_mem_mib" \
    --arg max_host_ram_percent "$max_host_ram_percent" '
      def pages_for($ram_mib; $size_mib):
        ((($ram_mib + $size_mib - 1) / $size_mib) | floor);

      [
        $vms
        | to_entries[]
        | .value.hugepages as $hp
        | select(($hp.enabled // false) == true)
        | {
            name: .key,
            ram_mib: (.value.ram_mib | tonumber),
            size_mib: (($hp.size_mib // 2) | tonumber),
            nodeset: ($hp.nodeset // null)
          }
        | . + { pages: pages_for(.ram_mib; .size_mib) }
      ] as $enabled_vms
      | ($enabled_vms | map(.size_mib) | unique) as $page_sizes
      | ($enabled_vms | map(.ram_mib) | add // 0) as $total_mib
      | ($enabled_vms | map(.pages) | add // 0) as $page_count
      | {
          hugepages_enabled: (($enabled_vms | length) > 0),
          hugepages_size_mib: (if ($page_sizes | length) == 1 then $page_sizes[0] elif ($page_sizes | length) == 0 then 2 else null end),
          hugepages_page_sizes_mib: $page_sizes,
          hugepages_count: $page_count,
          hugepages_total_mib: $total_mib,
          hugepages_vms: $enabled_vms,
          hugepages_mixed_page_sizes: (($page_sizes | length) > 1),
          hugepages_host_mem_total_mib: ($host_mem_mib | tonumber),
          hugepages_max_host_ram_percent: ($max_host_ram_percent | tonumber),
          hugepages_requested_host_ram_percent: (
            if ($host_mem_mib | tonumber) > 0
            then (($total_mib * 10000 / ($host_mem_mib | tonumber)) | round / 100)
            else 0
            end
          )
        }
    '
)"

if [ -n "$write_file" ]; then
  case "$write_file" in
    /*) ;;
    *) write_file="$(pwd)/$write_file" ;;
  esac
  mkdir -p "$(dirname "$write_file")"
  printf '%s\n' "$plan_json" > "$write_file"
fi

if [ "$json_only" = true ]; then
  printf '%s\n' "$plan_json"
else
  echo "Hugepages plan"
  echo "tfvars: $tfvars"
  echo

  if [ "$(printf '%s\n' "$plan_json" | jq -r '.hugepages_enabled')" != "true" ]; then
    echo "No VM has hugepages enabled."
  else
    printf '%s\n' "$plan_json" |
      jq -r '.hugepages_vms[] | "- \(.name): \(.ram_mib) MiB RAM -> \(.pages) hugepages @ \(.size_mib) MiB"'
    echo
    printf '%s\n' "$plan_json" |
      jq -r '"Total reservation: \(.hugepages_total_mib) MiB, \(.hugepages_count) pages @ \(.hugepages_size_mib) MiB"'
    printf '%s\n' "$plan_json" |
      jq -r '"Host memory: \(.hugepages_host_mem_total_mib) MiB, requested: \(.hugepages_requested_host_ram_percent)% of host RAM"'
  fi

  if [ -n "$write_file" ]; then
    echo
    echo "Wrote Ansible extra vars: $write_file"
  fi
fi

if [ "$(printf '%s\n' "$plan_json" | jq -r '.hugepages_mixed_page_sizes')" = "true" ]; then
  echo "Warning: mixed hugepage sizes are not supported by the Ansible host prep role yet." >&2
fi

requested_percent="$(printf '%s\n' "$plan_json" | jq -r '.hugepages_requested_host_ram_percent')"
too_much="$(
  awk -v requested="$requested_percent" -v max="$max_host_ram_percent" 'BEGIN { print (requested > max) ? "true" : "false" }'
)"

if [ "$too_much" = "true" ]; then
  echo "Warning: requested hugepages exceed ${max_host_ram_percent}% of host RAM. Reduce VM hugepages or RAM before applying." >&2
fi
