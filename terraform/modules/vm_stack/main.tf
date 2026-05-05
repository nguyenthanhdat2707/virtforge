


resource "libvirt_pool" "pool" {
  name = nonsensitive(var.common.pool.name)
  type = "dir"

  target = {
    path = nonsensitive(var.common.pool.path)
  }
}


resource "libvirt_network" "net" {
  for_each = local.networks

  name      = each.key
  forward   = { mode = "nat" }
  bridge    = { name = "virbr-${each.key}" }
  autostart = true

  ips = [{
    family  = each.value.family
    address = each.value.address
    prefix  = each.value.prefix
  }]

  lifecycle {
    precondition {
      condition = alltrue([
        for ip in local.networks_grouped[each.key] : ip == each.value
      ])
      error_message = "bridge_network '${each.key}' đang được nhiều VM dùng chung nhưng net_ip không giống nhau. Hãy thống nhất net_ip hoặc tách networks thành biến riêng."
    }
  }
}


resource "libvirt_volume" "base" {
  name = "${local.common_project}-${local.common_env}-base.qcow2"
  pool = libvirt_pool.pool.name

  create = {
    content = {
      url = nonsensitive(var.common.base_image_path)
    }
  }

  target = {
    format = { type = "qcow2" }
  }
}

resource "libvirt_volume" "vm_disk" {
  for_each = var.vms

  name = "${local.domain_name[each.key]}.qcow2"
  pool = libvirt_pool.pool.name

  capacity = each.value.disk_gb * 1024 * 1024 * 1024

  target = {
    format = { type = "qcow2" }
  }

  backing_store = {
    path   = libvirt_volume.base.path
    format = { type = "qcow2" }
  }
}


resource "libvirt_cloudinit_disk" "seed" {
  for_each = var.vms

  name           = "${local.domain_name[each.key]}-seed.iso"
  user_data      = local.user_data[each.key]
  meta_data      = local.meta_data[each.key]
  network_config = local.network_config[each.key]
}

resource "libvirt_volume" "seed_iso" {
  for_each = var.vms

  name = "${local.domain_name[each.key]}-seed.iso"
  pool = libvirt_pool.pool.name

  create = {
    content = {
      url = libvirt_cloudinit_disk.seed[each.key].path
    }
  }

  target = {
    format = { type = "iso" }
  }

  lifecycle {
    ignore_changes = [create]
  }
}

#
resource "libvirt_domain" "vm" {
  for_each = var.vms

  name        = local.domain_name[each.key]
  vcpu        = each.value.vcpu
  memory      = each.value.ram_mib
  memory_unit = "MiB"
  type        = "kvm"
  running     = true
  autostart   = true

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [{ dev = "hd" }]
  }

  features = { acpi = true }

  devices = {
    disks = [
      {
        driver = { name = "qemu", type = "qcow2" }
        source = {
          volume = {
            pool   = libvirt_pool.pool.name
            volume = libvirt_volume.vm_disk[each.key].name
          }
        }
        target = { dev = "vda", bus = "virtio" }
      },
      {
        device = "cdrom"
        driver = { name = "qemu", type = "raw" }
        source = {
          volume = {
            pool   = libvirt_pool.pool.name
            volume = libvirt_volume.seed_iso[each.key].name
          }
        }
        target = { dev = "sdb", bus = "sata" }
      }
    ]

    interfaces = [
      {
        model = { type = "virtio" }
        mac   = { address = each.value.mac }
        source = {
          network = {
            network = libvirt_network.net[each.value.bridge_network].name
          }
        }
      }
    ]

    serials = [
      { type = "pty", target_port = 0 }
    ]

    consoles = [
      { type = "pty", target_type = "serial", target_port = 0 }
    ]

    graphics = [
      {
        vnc = {
          auto_port = true
          listen    = "127.0.0.1"
        }
      }
    ]
  }
}


output "networks_created" {
  value = keys(local.networks)
}

output "vm_to_network" {
  value = { for k, v in var.vms : k => v.bridge_network }
}
