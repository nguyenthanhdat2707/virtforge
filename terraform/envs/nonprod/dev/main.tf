

provider "libvirt" {
  uri = nonsensitive(var.common.libvirt_uri)
}

module "kvm" {
  source = "../../../modules/vm_stack"

  common = var.common
  vms    = var.vms
}
