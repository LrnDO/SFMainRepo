output "k8s_node_1_external_ip" {
  description = "External IP address of k8s-node-1"
  value       = yandex_compute_instance.k8s-node-1.network_interface.0.nat_ip_address
}

output "k8s_CP_external_ip" {
  description = "External IP address of k8s-cp"
  value       = yandex_compute_instance.k8s-cp.network_interface.0.nat_ip_address
}

output "monitoring_vm_external_ip" {
  description = "External IP address of srv"
  value       = yandex_compute_instance.srv.network_interface.0.nat_ip_address
}

output "k8s_node_1_internal_ip" {
  description = "Internal IP address of k8s-node-1"
  value       = yandex_compute_instance.k8s-node-1.network_interface.0.ip_address
}

output "k8s_CP_internal_ip" {
  description = "Internal IP address of k8s-cp"
  value       = yandex_compute_instance.k8s-cp.network_interface.0.ip_address
}

output "monitoring_vm_internal_ip" {
  description = "Internal IP address of srv"
  value       = yandex_compute_instance.srv.network_interface.0.ip_address
}
