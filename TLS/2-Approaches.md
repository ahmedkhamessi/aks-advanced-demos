# TLS Termination Approaches

## 1. Terminating at the Ingress Level

### 1.1. cert-manager (Open Source)
- One of the most popular Kubernetes-native solutions for automatically provisioning and renewing TLS certificates.
- Integrates with various Certificate Authorities (CAs), such as Let’s Encrypt, HashiCorp Vault, and more.
- Supports creating `Issuer` and `ClusterIssuer` resources to handle certificate requests automatically.
- Can watch Ingress resources to trigger certificate generation and update them automatically.
- [Official documentation](https://cert-manager.io/docs/tutorials/getting-started-aks-letsencrypt/)

### 1.2. Azure Key Vault Integration
- Use cert-manager’s Azure Key Vault issuer plugin to store certificates in Azure Key Vault or retrieve existing certificates from it.
- Offers centralized storage and policy-based control over secrets.
- Can be combined with the Azure Key Vault Provider for Secret Store CSI Driver to pull secrets from Key Vault into Kubernetes.

### 1.3. Let’s Encrypt (via ACME protocol)
- Often configured through cert-manager using the ACME HTTP challenge or DNS challenge.
- Provides publicly trusted certificates at no additional cost.
- Simplifies periodic certificate re-issuance and rotation.

### 1.4 practical approach and limitations
-  Out of the box, cert-manager does not directly “push” newly issued Let’s Encrypt certificates into Azure Key Vault. You must add a post-issuance step or another mechanism to upload those certificates to Key Vault.

## 2. Terminating at the Layer 7 Level

<!-- Add details here as needed -->