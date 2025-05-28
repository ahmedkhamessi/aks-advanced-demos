# AKS Cluster Setup

The code in this folder has for aim to create a basic cluster that can be used for most scenarios.
It will create a resource group and an AKS cluster with min two nodes.

## Overview

This setup provides a starting point for deploying workloads to Azure Kubernetes Service (AKS) in a repeatable way. The configuration is suitable for development, testing, or production environments with minimal adjustments.

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and logged in
- Sufficient Azure subscription permissions to create resource groups and AKS clusters

## Usage

1. Clone this repository or navigate to this folder.
2. Review and update any parameters in the deployment scripts or templates as needed.
3. Run the provided scripts or follow the instructions in the deployment files to create the resources.

### Using Terraform

You can also use Terraform to provision the resource group and AKS cluster. Make sure you have [Terraform](https://www.terraform.io/downloads.html) installed and configured with your Azure credentials.

```sh
# Initialize Terraform
terraform init

# Review the execution plan
terraform plan

# Apply the configuration to create resources
terraform apply
```

> **Note:** Update the Terraform variable values as needed before running `terraform apply`.

## Resources Created

- **Resource Group**: A logical container for the AKS cluster and related resources.
- **AKS Cluster**: Azure Kubernetes Service cluster with a minimum of two nodes.

## Next Steps

- Deploy your workloads to the AKS cluster.
- Configure monitoring, scaling, and security as needed for your scenario.

## Cleanup

To avoid ongoing charges, remember to delete the resource group when you are finished:

```sh
az group delete --name <your-resource-group-name>
```

## Support

For issues or questions, please open an issue in this repository.