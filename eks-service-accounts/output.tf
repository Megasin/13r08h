output "kubernetes_service_account_id" {
  description = "Kubernetes Service Account ID."
  value       = kubernetes_service_account.main.id
}
