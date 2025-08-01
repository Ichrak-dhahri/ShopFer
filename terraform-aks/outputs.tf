output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  description = "AKS cluster ID"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.aks_rg.name
}

output "location" {
  description = "Location"
  value       = azurerm_resource_group.aks_rg.location
}

output "kube_config" {
  description = "Kubernetes config"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "kubernetes_version" {
  description = "Kubernetes version used"
  value       = azurerm_kubernetes_cluster.aks.kubernetes_version
}