variable "cluster_name" {
  description = "Talos/Kubernetes cluster name."
  type        = string
  default     = "iots-lab"
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

variable "talos_iso_url" {
  description = "Override Talos ISO URL. Empty means GitHub release metal-amd64.iso for talos_version."
  type        = string
  default     = ""
}

variable "controlplane_vcpu" {
  description = "vCPU count for the single Talos control-plane VM."
  type        = number
  default     = 4
}

variable "controlplane_memory_mib" {
  description = "Memory for the single Talos control-plane VM."
  type        = number
  default     = 4096
}

variable "controlplane_disk_bytes" {
  description = "System disk size in bytes. Default is 80 GiB."
  type        = number
  default     = 85899345920
}

variable "controlplane_mac" {
  description = "Stable MAC so libvirt DHCP tends to keep the same IP across reboots."
  type        = string
  default     = "52:54:00:13:37:11"
}

variable "controlplane_ip" {
  description = "Static IPv4 address for the control-plane VM."
  type        = string
  default     = "192.168.130.11"
}

variable "worker_vcpu" {
  description = "vCPU count for the Talos worker VM."
  type        = number
  default     = 6
}

variable "worker_memory_mib" {
  description = "Memory for the Talos worker VM."
  type        = number
  default     = 6144
}

variable "worker_disk_bytes" {
  description = "Worker disk size in bytes. Default is 100 GiB."
  type        = number
  default     = 107374182400
}

variable "worker_mac" {
  description = "Stable MAC for the worker VM."
  type        = string
  default     = "52:54:00:13:37:12"
}

variable "worker_ip" {
  description = "Static IPv4 address for the worker VM."
  type        = string
  default     = "192.168.130.12"
}
