provider "libvirt" {}

resource "libvirt_volume" "debian_cloud_base" {
  name = "debian-12-generic-amd64.qcow2"
  pool = "default"
  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      url = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    }
  }
}

variable "vm_specs" {
  type = map(map(string))
  default = {
    jumpbox = {
      hostname = "jumpbox"
      memory = 512
      memory_unit = "MiB"
      capacity = 10
      capacity_unit = "GiB"
    }
    server = {
      hostname = "server"
      memory = 2
      memory_unit = "GiB"
      capacity = 20
      capacity_unit = "GiB"
    }
    node0 = {
      hostname = "node-0"
      memory = 2
      memory_unit = "GiB"
      capacity = 20
      capacity_unit = "GiB"
    }
    node1 = {
      hostname = "node-1"
      memory = 2
      memory_unit = "GiB"
      capacity = 20
      capacity_unit = "GiB"
    }
  }
}

resource "libvirt_network" "cluster_net" {
  name = "cluster"
  forward = {
    mode = "nat"
  }
  ips = [{
    address = "192.168.122.0"
    netmask = "255.255.255.0"
  }]
}

resource "libvirt_domain" "vms" {
  for_each = var.vm_specs
  name = "cluster-${each.value.hostname}"
  memory = each.value.memory
  memory_unit = each.value.memory_unit
  vcpu = 1
  type = "kvm"

  os = {
    type = "hvm"
    type_arch = "x86_64"
    type_machine = "q35"
    boot_devices = [
      {
        dev = "hd"
      }
    ]
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool = libvirt_volume.boot_volumes[each.key].pool
            volume = libvirt_volume.boot_volumes[each.key].name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        source = {
          volume = {
            pool = libvirt_volume.cloudinit_volumes[each.key].pool
            volume = libvirt_volume.cloudinit_volumes[each.key].name
          }
        }
        target = {
          dev = "vdb"
          bus = "virtio"
        }
      }
    ]
    interfaces = [
      {
        source = {
          network = {
            network = libvirt_network.cluster_net.name
          }
        }
      }
    ]
    graphics = [{
      spice = {}
    }]
  }
}

resource "libvirt_cloudinit_disk" "inits" {
  for_each = var.vm_specs
  name = "cluster-init-${each.key}"
  user_data = file("user-data.yaml")
  meta_data = yamlencode({
    instance-id    = each.key
    local-hostname = each.value.hostname
  })
}

resource "libvirt_volume" "cloudinit_volumes" {
  for_each = var.vm_specs
  name = "cluster-cloudinit-${each.key}.iso"
  pool = "default"

  create = {
    content = {
      url = libvirt_cloudinit_disk.inits[each.key].path
    }
  }
}

resource "libvirt_volume" "boot_volumes" {
  for_each = var.vm_specs
  name = "cluster-boot-${each.key}.qcow2"
  pool = "default"
  target = {
    format = {
      type = "qcow2"
    }
  }
  
  capacity = each.value.capacity
  capacity_unit = each.value.capacity_unit

  backing_store = {
    path = libvirt_volume.debian_cloud_base.path
    format = libvirt_volume.debian_cloud_base.target.format
  }
}
