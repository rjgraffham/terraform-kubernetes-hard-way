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

#resource "libvirt_network" "cluster_net" {
#}
#
#resource "libvirt_domain" "jumpbox" {
#}
#
#resource "libvirt_domain" "server" {
#}
#
#resource "libvirt_domain" "node-0" {
#}
#
#resource "libvirt_domain" "node-1" {
#}
