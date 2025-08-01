data "azurerm_kubernetes_service_versions" "current" {
  location = var.location
}

resource "azurerm_resource_group" "aks_rg" {
  name     = var.resource_group_name
  location = var.location
  
  tags = {
    Environment = "Dev"
    Project     = "ShopFer"
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = "${var.cluster_name}-dns"
  
  # Utiliser la dernière version stable disponible ou spécifier une version supportée
  kubernetes_version = var.kubernetes_version

  default_node_pool {
    name                = "default"
    node_count         = var.node_count
    vm_size            = var.vm_size
    os_disk_size_gb    = 30
    os_disk_type       = "Managed"
    ultra_ssd_enabled  = false
    
    # Options pour économiser les coûts
    enable_auto_scaling = false
    type               = "VirtualMachineScaleSets"
    
    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  # Configuration pour le tier gratuit
  sku_tier = "Free"
  
  # Désactiver des fonctionnalités premium pour réduire les coûts
  role_based_access_control_enabled = true
  run_command_enabled              = true
  
  tags = {
    Environment = "Dev"
    Project     = "ShopFer"
  }
}