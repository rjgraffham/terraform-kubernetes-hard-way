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
          file = {
            file = "/path/from/volume/output"
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        source = {
          file = {
            file = "/path/from/cloudinit/output"
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
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = "cluster-internal"
          }
        }
      },
      {
        source = {
          bridge = {
            bridge = "virbr0"
          }
        }
      }
    ]
  }
}
