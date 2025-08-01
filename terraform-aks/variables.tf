variable "resource_group_name" {
  type        = string
  description = "RG name in Azure"
  default     = "rg-shopfer-aks"
}

variable "location" {
  type        = string
  description = "Resources location in Azure"
  default     = "francecentral"
}

variable "cluster_name" {
  type        = string
  description = "AKS name in Azure"
  default     = "aks-shopfer"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version"
  default     = "1.30.14"  # Version stable recommandée avec KubernetesOfficial
}

variable "node_count" {
  type        = number
  description = "Number of AKS worker nodes"
  default     = 1
}

variable "vm_size" {
  type        = string
  description = "VM size for nodes"
  default     = "Standard_B2s"
}