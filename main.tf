provider "libvirt" {}

variable "running" {
  type = bool
  default = true
}

variable "ip_prefix" {
  type = string
  default = "192.168.122"
}

variable "mac_prefix" {
  type = string
  default = "de:2a:22:d8:2a"  # must be a locally administered unicast prefix
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
      ip_last_octet = "2"
      mac_last_octet = "02"
    }
    server = {
      hostname = "server"
      memory = 2
      memory_unit = "GiB"
      capacity = 20
      capacity_unit = "GiB"
      ip_last_octet = "3"
      mac_last_octet = "03"
    }
    node0 = {
      hostname = "node-0"
      memory = 2
      memory_unit = "GiB"
      capacity = 20
      capacity_unit = "GiB"
      ip_last_octet = "4"
      mac_last_octet = "04"
    }
    node1 = {
      hostname = "node-1"
      memory = 2
      memory_unit = "GiB"
      capacity = 20
      capacity_unit = "GiB"
      ip_last_octet = "5"
      mac_last_octet = "05"
    }
  }
}

resource "libvirt_network" "cluster_net" {
  name = "cluster"
  forward = {
    mode = "nat"
  }
  ips = [{
    address = "${var.ip_prefix}.1"
    netmask = "255.255.255.0"
    dhcp = {
      hosts = [ for vm_key, vm_spec in var.vm_specs: {
        mac = "${var.mac_prefix}:${vm_spec.mac_last_octet}"
        ip = "${var.ip_prefix}.${vm_spec.ip_last_octet}"
        name = "cluster-${vm_key}"
      }]
      ranges = [{
        start = "${var.ip_prefix}.100"
        end = "${var.ip_prefix}.254"
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

  running = var.running

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

        mac = {
          address = "${var.mac_prefix}:${each.value.mac_last_octet}"
          type = "static"
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
