locals {
  common_env     = nonsensitive(var.common.env)
  common_project = nonsensitive(var.common.project)

  domain_name = {
    for k, v in var.vms : k => "${local.common_project}-${local.common_env}-${v.vm_name}"
  }

  networks_grouped = {
    for k, v in var.vms : v.bridge_network => v.net_ip...
  }

  networks = {
    for net_name, ips in local.networks_grouped : net_name => ips[0]
  }

  user_data = {
    for k, v in var.vms : k => templatefile("${path.module}/templates/user-data.yaml.tftpl", {
      ssh_user       = nonsensitive(var.common.access.ssh_user)
      ssh_public_key = nonsensitive(var.common.access.ssh_public_key)
      ssh_password   = var.common.access.ssh_password
      hostname       = local.domain_name[k]
    })
  }

  meta_data = {
    for k, v in var.vms : k => templatefile("${path.module}/templates/meta-data.yaml.tftpl", {
      instance_id = local.domain_name[k]
      hostname    = local.domain_name[k]
    })
  }

  network_config = {
    for k, v in var.vms : k => templatefile("${path.module}/templates/network-config.yaml.tftpl", {
      mac    = v.mac
      ip     = v.ip
      prefix = v.net_ip.prefix
      gw     = v.gw
      dns    = v.dns
    })
  }
}
