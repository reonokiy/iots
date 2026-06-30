locals {
  controlplane_name = "${var.cluster_name}-cp-1"
  worker_name       = "${var.cluster_name}-worker-1"
  talos_iso_url     = var.talos_iso_url != "" ? var.talos_iso_url : "https://github.com/siderolabs/talos/releases/download/${var.talos_version}/metal-amd64.iso"
  cluster_endpoint  = "https://${var.controlplane_ip}:6443"
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
    options {
      option_name  = "dhcp-host"
      option_value = "${var.controlplane_mac},${var.controlplane_ip},${local.controlplane_name}"
    }

    options {
      option_name  = "dhcp-host"
      option_value = "${var.worker_mac},${var.worker_ip},${local.worker_name}"
    }
  }
}

resource "libvirt_volume" "controlplane_iso" {
  name   = "talos-${var.talos_version}-metal-amd64.iso"
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

resource "libvirt_volume" "worker_iso" {
  name   = "talos-${var.talos_version}-metal-amd64-worker.iso"
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

resource "libvirt_volume" "controlplane_disk" {
  name   = "${local.controlplane_name}.qcow2"
  pool   = libvirt_pool.talos.name
  size   = var.controlplane_disk_bytes
  format = "qcow2"
}

resource "libvirt_volume" "worker_disk" {
  name   = "${local.worker_name}.qcow2"
  pool   = libvirt_pool.talos.name
  size   = var.worker_disk_bytes
  format = "qcow2"
}

resource "libvirt_domain" "controlplane" {
  name      = local.controlplane_name
  memory    = var.controlplane_memory_mib
  vcpu      = var.controlplane_vcpu
  autostart = true

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.controlplane_disk.id
  }

  disk {
    volume_id = libvirt_volume.controlplane_iso.id
  }

  network_interface {
    network_id = libvirt_network.talos.id
    mac        = var.controlplane_mac
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
        <xsl:template match="disk[source/@volume='talos-${var.talos_version}-metal-amd64.iso']">
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

resource "libvirt_domain" "worker" {
  name      = local.worker_name
  memory    = var.worker_memory_mib
  vcpu      = var.worker_vcpu
  autostart = true

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.worker_disk.id
  }

  disk {
    volume_id = libvirt_volume.worker_iso.id
  }

  network_interface {
    network_id = libvirt_network.talos.id
    mac        = var.worker_mac
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
        <xsl:template match="disk[source/@volume='talos-${var.talos_version}-metal-amd64-worker.iso']">
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
