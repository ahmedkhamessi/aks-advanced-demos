variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "aks-demo-rg"
}

variable "resource_group_location" {
  description = "The Azure region to deploy the resource group"
  type        = string
  default     = "GermanyWestCentral"
}

variable "aks_location" {
  description = "The Azure region to deploy the AKS cluster"
  type        = string
  default     = "SwedenCentral"
}

variable "aks_cluster_name" {
  description = "The name of the AKS cluster"
  type        = string
  default     = "aks-demo-cluster"
}

variable "node_count" {
  description = "The number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "The size of the Virtual Machines in the node pool"
  type        = string
  default     = "Standard_D4ds_v5"
}
