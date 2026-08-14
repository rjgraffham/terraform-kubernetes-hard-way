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
      url = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.qcow2"
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
    address = "192.168.122.1"
    netmask = "255.255.255.0"
    dhcp = {
      ranges = [{
        start = "192.168.122.100"
        end = "192.168.122.254"
      }]
    }
  }]
}

resource "libvirt_domain" "vms" {
  for_each = var.vm_specs
  name = "cluster-${each.value.hostname}"
  memory = each.value.memory
  memory_unit = each.value.memory_unit
  vcpu = 1
  type = "kvm"

  metadata = {
    xml = <<-EOX
      <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
        <libosinfo:os id="http://debian.org/debian/12"/>
      </libosinfo:libosinfo>
    EOX
  }

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

  cpu = {
    mode = "host-passthrough"
  }

  features = {
    acpi = true
    apic = {}
  }

  clock = {
    timer = [
      {
        name = "rtc"
        tick_policy = "catchup"
      },
      {
        name = "pit"
        tick_policy = "delay"
      },
      {
        name = "hpet"
        present = "no"
      }
    ]
  }

  pm = {
    suspend_to_disk = {
      enabled = "no"
    }
    suspend_to_mem = {
      enabled = "no"
    }
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
        driver = {
          type = "qcow2"
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
            network = libvirt_network.cluster_net.name
          }
        }
      }
    ]
    graphics = [{
      spice = {}
    }]
    rngs = [{
      model = "virtio"
      backend = {
        random = "/dev/urandom"
      }
    }]
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
