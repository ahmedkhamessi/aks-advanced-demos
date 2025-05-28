# Demo Structure

This repository contains demos and foundational materials for advanced Azure Kubernetes Service (AKS) scenarios, including cluster setup, Helm, TLS, service mesh, monitoring, and Azure Entra ID integration.
NOTE: The code is used for demonstration purposes and not suited for production environments.

## Structure Overview

- **Demos/ClusterSetup/**  
  Scripts and documentation for creating a basic AKS cluster, including Terraform and Azure CLI options.

- **Demos/Helm/**  
  Introduction to Helm, sample Helm charts, and scripts for packaging and deploying applications using Helm and Azure Container Registry (ACR).

- **Demos/TLS/**  
  Guides and decision trees for TLS termination approaches in AKS, including cert-manager, Azure Key Vault, and integration patterns.

- **Demos/MeshAndMonitoring/**  
  Lab guides and Bicep templates for setting up monitoring (Log Analytics, Grafana, Prometheus, Application Insights) and Istio service mesh on AKS.

- **Demos/EntraID/**  
  Samples and instructions for integrating Azure Entra ID (formerly Azure AD) with applications, including Key Vault access from .NET apps.


## Requirements

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and logged in
- [Terraform](https://www.terraform.io/downloads.html) (for infrastructure automation)
- [Helm](https://helm.sh/docs/intro/install/) (for Kubernetes package management)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (Kubernetes CLI)
- [.NET SDK 7.0+](https://dotnet.microsoft.com/en-us/download) (for .NET sample app)
- Sufficient Azure subscription permissions to create resource groups, AKS clusters, and related resources

## Support

For questions or issues, please open an issue in this repository.
