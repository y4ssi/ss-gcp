
output "nginx_service_external_ip" {
  description = "The external IP of the nginx service"
  value       = data.local_file.external_ip.content
}

output "kubernetes_cluster_name" {
  value = google_container_cluster.primary.name
}

output "kubernetes_cluster_endpoint" {
  value = google_container_cluster.primary.endpoint
}

output "kubernetes_cluster_ca_certificate" {
  value = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}
