provider "libvirt" {}

resource "libvirt_network" "cluster-net" {
}

resource "libvirt_domain" "jumpbox" {
}

resource "libvirt_domain" "server" {
}

resource "libvirt_domain" "node-0" {
}

resource "libvirt_domain" "node-1" {
}
