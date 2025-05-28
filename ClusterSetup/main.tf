# Terraform script to create a resource group and AKS cluster in Germany West Central
#
# - Resource group and AKS cluster are created in 'GermanyWestCentral'
# - AKS cluster has a minimum of 2 nodes
# - Follows Azure and Terraform best practices
# - No credentials are hardcoded; use environment variables or Azure authentication
# - Add error handling and comments for clarity

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "aks-demo-cluster"
    storage_account_name = "tfbackendstorage90"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "aks_rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = var.aks_cluster_name
  location            = var.aks_location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = "aksdemocluster"

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.node_vm_size
    # You can adjust node_count and vm_size as needed
  }

  identity {
    type = "SystemAssigned"
  }

  # Enable RBAC
  role_based_access_control_enabled = true

  # Network profile (optional, can be customized)
  network_profile {
    network_plugin = "azure"
    load_balancer_sku = "standard"
  }

  # Add tags for resource management
  tags = {
    environment = "demo"
    project     = "aks-basic-cluster"
  }
}

# Output the AKS cluster name and resource group
output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks_cluster.name
}

output "aks_resource_group" {
  value = azurerm_resource_group.aks_rg.name
}