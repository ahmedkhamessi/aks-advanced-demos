# Introduction to Helm

## What is Helm?
- Helm is the de-facto package manager for Kubernetes.
- It plays a key role in packaging, versioning, and deploying containerized applications.

### How Helm Evolved
- **Helm 2:** Used Tiller for in-cluster management.
- **Helm 3:** Removed Tiller, shifting to a client-only model for simplicity and security.

---

# Why Use Helm?

## Challenges Without Helm
- Managing multiple YAML files for complex applications.
- Difficult version control and manual rollbacks.

## Helm Advantages
- One-stop solution for packaging, versioning, and deploying applications.
- Straightforward rollback and upgrade mechanisms.
- Enhanced productivity with parameterized charts.

---

# Core Concepts and Terminology

## Charts
- Core package format containing Kubernetes manifests and templates.
- Standard structure: `Chart.yaml`, `values.yaml`, `templates/`.
- Reusable for different environments and use cases.

## Releases
- Each deployment of a chart is known as a **release**.
- Allows multiple versions to run simultaneously.
- Unique naming per release supports parallel environments.

## Helm Repositories
- Central or distributed storage locations for charts (public or private).
- Popular examples: Artifact Hub, private repositories (e.g., Azure Container Registry).

## Values and Templates
- `values.yaml` files parameterize charts.
- Go templating syntax enables flexible, dynamic manifest creation.

---

# Helm in the Context of Azure and AKS

## Why Helm on AKS?
- Simplifies packaging and deploying applications on Azure Kubernetes Service (AKS).
- Provides operational consistency with familiar Helm CLI commands.
- Integrates with CI/CD pipelines using Azure DevOps or GitHub Actions.

## Azure Container Registry (ACR) for Helm Charts
- Private, secure storage for Helm charts.
- Integrated security features (e.g., Azure RBAC, Private Link).
- Streamlined chart publishing and versioning for AKS deployments.