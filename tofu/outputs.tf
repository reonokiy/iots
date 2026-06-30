output "controlplane_name" {
  value = local.controlplane_name
}

output "worker_name" {
  value = local.worker_name
}

output "controlplane_ip" {
  value = var.controlplane_ip
}

output "worker_ip" {
  value = var.worker_ip
}

output "cluster_endpoint" {
  value = local.cluster_endpoint
}
