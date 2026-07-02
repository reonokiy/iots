variable "cluster_name" {
  description = "Talos/Kubernetes cluster name."
  type        = string
  default     = "iots-lab"
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint. Empty means the first control-plane IP on port 6443."
  type        = string
  default     = ""
}

variable "libvirt_uri" {
  description = "libvirt connection URI."
  type        = string
  default     = "qemu:///system"
}

variable "libvirt_pool_name" {
  description = "Dedicated libvirt storage pool for this lab."
  type        = string
  default     = "iots-lab"
}

variable "libvirt_pool_path" {
  description = "Host directory backing the libvirt storage pool."
  type        = string
  default     = "/var/lib/libvirt/images/iots-lab"
}

variable "libvirt_network_name" {
  description = "Dedicated libvirt NAT network for this lab."
  type        = string
  default     = "iots-lab"
}

variable "libvirt_network_cidr" {
  description = "CIDR for the dedicated libvirt NAT network."
  type        = string
  default     = "192.168.130.0/24"
}

variable "talos_version" {
  description = "Talos Linux version."
  type        = string
  default     = "v1.13.5"
}

variable "kubernetes_version" {
  description = "Kubernetes version for Talos machine config generation."
  type        = string
  default     = "1.36.1"
}

variable "talos_iso_url" {
  description = "Override Talos ISO URL. Empty means GitHub release metal-amd64.iso for talos_version."
  type        = string
  default     = ""
}

variable "node_mac_prefix" {
  description = "First five MAC address octets used for generated Talos VM MACs."
  type        = string
  default     = "52:54:00:13:37"

  validation {
    condition     = can(regex("^([0-9A-Fa-f]{2}:){4}[0-9A-Fa-f]{2}$", var.node_mac_prefix))
    error_message = "node_mac_prefix must contain exactly five MAC address octets, for example 52:54:00:13:37."
  }
}

variable "controlplane_count" {
  description = "Number of Talos control-plane VMs."
  type        = number
  default     = 1

  validation {
    condition     = var.controlplane_count >= 1
    error_message = "controlplane_count must be at least 1."
  }
}

variable "controlplane_vcpu" {
  description = "vCPU count for each Talos control-plane VM."
  type        = number
  default     = 4
}

variable "controlplane_memory_mib" {
  description = "Memory for each Talos control-plane VM."
  type        = number
  default     = 4096
}

variable "controlplane_disk_bytes" {
  description = "Control-plane system disk size in bytes. Default is 80 GiB."
  type        = number
  default     = 85899345920
}

variable "controlplane_ip_start" {
  description = "First host number in libvirt_network_cidr used for generated control-plane IPs."
  type        = number
  default     = 11
}

variable "controlplane_mac_start" {
  description = "First generated control-plane MAC suffix, as a decimal number. Default 17 renders as hex 11."
  type        = number
  default     = 17
}

variable "worker_count" {
  description = "Number of Talos worker VMs."
  type        = number
  default     = 1

  validation {
    condition     = var.worker_count >= 1
    error_message = "worker_count must be at least 1 for this lab topology."
  }
}

variable "worker_vcpu" {
  description = "vCPU count for each Talos worker VM."
  type        = number
  default     = 6
}

variable "worker_memory_mib" {
  description = "Memory for each Talos worker VM."
  type        = number
  default     = 6144
}

variable "worker_disk_bytes" {
  description = "Worker system disk size in bytes. Default is 100 GiB."
  type        = number
  default     = 107374182400
}

variable "worker_ip_start" {
  description = "First host number in libvirt_network_cidr used for generated worker IPs."
  type        = number
  default     = 12
}

variable "worker_mac_start" {
  description = "First generated worker MAC suffix, as a decimal number. Default 18 renders as hex 12."
  type        = number
  default     = 18
}

variable "controlplane_mac" {
  description = "Deprecated single-node override for iots-lab-cp-1 MAC. Prefer controlplane_mac_start."
  type        = string
  default     = ""
}

variable "controlplane_ip" {
  description = "Deprecated single-node override for iots-lab-cp-1 IP. Prefer controlplane_ip_start."
  type        = string
  default     = ""
}

variable "worker_mac" {
  description = "Deprecated single-node override for iots-lab-worker-1 MAC. Prefer worker_mac_start."
  type        = string
  default     = ""
}

variable "worker_ip" {
  description = "Deprecated single-node override for iots-lab-worker-1 IP. Prefer worker_ip_start."
  type        = string
  default     = ""
}
