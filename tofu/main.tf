locals {
  talos_iso_url = var.talos_iso_url != "" ? var.talos_iso_url : "https://github.com/siderolabs/talos/releases/download/${var.talos_version}/metal-amd64.iso"

  controlplane_node_list = [
    for index in range(var.controlplane_count) : {
      index      = index + 1
      role       = "controlplane"
      role_order = 0
      name       = "${var.cluster_name}-cp-${index + 1}"
      ip         = index == 0 && var.controlplane_ip != "" ? var.controlplane_ip : cidrhost(var.libvirt_network_cidr, var.controlplane_ip_start + index)
      mac        = index == 0 && var.controlplane_mac != "" ? var.controlplane_mac : "${var.node_mac_prefix}:${format("%02x", var.controlplane_mac_start + index)}"
      vcpu       = var.controlplane_vcpu
      memory_mib = var.controlplane_memory_mib
      disk_bytes = var.controlplane_disk_bytes
      iso_name   = index == 0 ? "talos-${var.talos_version}-metal-amd64.iso" : "talos-${var.talos_version}-metal-amd64-cp-${index + 1}.iso"
    }
  ]

  worker_node_list = [
    for index in range(var.worker_count) : {
      index      = index + 1
      role       = "worker"
      role_order = 1
      name       = "${var.cluster_name}-worker-${index + 1}"
      ip         = index == 0 && var.worker_ip != "" ? var.worker_ip : cidrhost(var.libvirt_network_cidr, var.worker_ip_start + index)
      mac        = index == 0 && var.worker_mac != "" ? var.worker_mac : "${var.node_mac_prefix}:${format("%02x", var.worker_mac_start + index)}"
      vcpu       = var.worker_vcpu
      memory_mib = var.worker_memory_mib
      disk_bytes = var.worker_disk_bytes
      iso_name   = index == 0 ? "talos-${var.talos_version}-metal-amd64-worker.iso" : "talos-${var.talos_version}-metal-amd64-worker-${index + 1}.iso"
    }
  ]

  node_list          = concat(local.controlplane_node_list, local.worker_node_list)
  nodes              = { for node in local.node_list : node.name => node }
  controlplane_nodes = { for node in local.controlplane_node_list : node.name => node }
  worker_nodes       = { for node in local.worker_node_list : node.name => node }
  controlplane_ips   = [for node in local.controlplane_node_list : node.ip]
  worker_ips         = [for node in local.worker_node_list : node.ip]
  cluster_endpoint   = var.cluster_endpoint != "" ? var.cluster_endpoint : "https://${local.controlplane_node_list[0].ip}:6443"
}

resource "libvirt_pool" "talos" {
  name = var.libvirt_pool_name
  type = "dir"

  target {
    path = var.libvirt_pool_path
  }
}

resource "libvirt_network" "talos" {
  name      = var.libvirt_network_name
  mode      = "nat"
  domain    = "${var.cluster_name}.local"
  addresses = [var.libvirt_network_cidr]

  dns {
    enabled = true
  }

  dhcp {
    enabled = true
  }

  dnsmasq_options {
    dynamic "options" {
      for_each = local.nodes

      content {
        option_name  = "dhcp-host"
        option_value = "${options.value.mac},${options.value.ip},${options.value.name}"
      }
    }
  }

  lifecycle {
    precondition {
      condition     = length(distinct([for node in local.node_list : node.ip])) == length(local.node_list)
      error_message = "Talos node IP addresses must be unique. Adjust controlplane_ip_start, worker_ip_start, or the legacy single-node IP overrides."
    }

    precondition {
      condition     = length(distinct([for node in local.node_list : lower(node.mac)])) == length(local.node_list)
      error_message = "Talos node MAC addresses must be unique. Adjust controlplane_mac_start, worker_mac_start, or the legacy single-node MAC overrides."
    }
  }
}

resource "libvirt_volume" "iso" {
  for_each = local.nodes

  name   = each.value.iso_name
  pool   = libvirt_pool.talos.name
  source = local.talos_iso_url
  format = "iso"

  lifecycle {
    ignore_changes = [
      format,
      size,
      source,
    ]
  }
}

resource "libvirt_volume" "disk" {
  for_each = local.nodes

  name   = "${each.value.name}.qcow2"
  pool   = libvirt_pool.talos.name
  size   = each.value.disk_bytes
  format = "qcow2"
}

resource "libvirt_domain" "node" {
  for_each = local.nodes

  name      = each.value.name
  memory    = each.value.memory_mib
  vcpu      = each.value.vcpu
  autostart = true

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.disk[each.key].id
  }

  disk {
    volume_id = libvirt_volume.iso[each.key].id
  }

  network_interface {
    network_id = libvirt_network.talos.id
    mac        = each.value.mac
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  xml {
    xslt = <<-XSLT
      <?xml version="1.0"?>
      <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
        <xsl:output omit-xml-declaration="yes"/>
        <xsl:template match="@*|node()">
          <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
          </xsl:copy>
        </xsl:template>
        <xsl:template match="disk[target/@dev='vda']">
          <xsl:copy>
            <xsl:apply-templates select="@*|node()[not(self::boot)]"/>
            <boot order="1"/>
          </xsl:copy>
        </xsl:template>
        <xsl:template match="disk[source/@volume='${each.value.iso_name}']">
          <xsl:copy>
            <xsl:apply-templates select="@*|node()[not(self::boot)]"/>
            <boot order="2"/>
          </xsl:copy>
        </xsl:template>
      </xsl:stylesheet>
    XSLT
  }

  lifecycle {
    ignore_changes = [
      cmdline,
      console,
      disk,
      fw_cfg_name,
      graphics,
      network_interface[0].addresses,
      network_interface[0].hostname,
      network_interface[0].network_name,
      network_interface[0].wait_for_lease,
      nvram,
      qemu_agent,
      type,
      xml,
    ]
  }
}
