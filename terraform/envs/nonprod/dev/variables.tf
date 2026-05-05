variable "common" {
  type = object({
    env         = string
    project     = string
    libvirt_uri = string

    pool = object({
      name = string
      path = string
    })

    base_image_path = string

    access = object({
      ssh_user       = string
      ssh_public_key = string

      ansible_private_key_path = string

      ssh_password = string
    })
  })

  sensitive = true
}

variable "vms" {
  type = map(object({
    # per-VM naming + network
    vm_name        = string
    bridge_network = string

    net_ip = object({
      family  = string
      address = string
      prefix  = number
    })

    # per-VM sizing
    vcpu    = number
    ram_mib = number
    disk_gb = number

    # per-VM static IP config (cloud-init)
    cidr = string
    ip   = string
    gw   = string
    mac  = string
    dns  = list(string)
  }))
}
