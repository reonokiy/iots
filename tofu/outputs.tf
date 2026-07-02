output "cluster_name" {
  value = var.cluster_name
}

output "cluster_endpoint" {
  value = local.cluster_endpoint
}

output "gateway_ip" {
  value = cidrhost(var.libvirt_network_cidr, 1)
}

output "network_prefix" {
  value = tonumber(split("/", var.libvirt_network_cidr)[1])
}

output "talos_version" {
  value = var.talos_version
}

output "kubernetes_version" {
  value = var.kubernetes_version
}

output "nodes" {
  value = local.nodes
}

output "controlplane_nodes" {
  value = local.controlplane_nodes
}

output "worker_nodes" {
  value = local.worker_nodes
}

output "controlplane_ips" {
  value = local.controlplane_ips
}

output "worker_ips" {
  value = local.worker_ips
}

output "controlplane_name" {
  value = local.controlplane_node_list[0].name
}

output "worker_name" {
  value = local.worker_node_list[0].name
}

output "controlplane_ip" {
  value = local.controlplane_node_list[0].ip
}

output "worker_ip" {
  value = local.worker_node_list[0].ip
}
