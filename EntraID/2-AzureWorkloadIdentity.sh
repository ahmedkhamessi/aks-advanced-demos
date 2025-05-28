# Parameters
RG=<ResourceGroupName>
LOC=<Location>
CLUSTER_NAME=<AKSClusterName>
UNIQUE_ID=$CLUSTER_NAME$RANDOM
ACR_NAME=$UNIQUE_ID
KEY_VAULT_NAME=$UNIQUE_ID

# Create the resource group
az group create -g $RG -l $LOC

# Create the cluster with the OIDC Issuer and Workload Identity enabled
az aks create -g $RG -n $CLUSTER_NAME \
    --node-count 1 \
    --enable-oidc-issuer \
    --enable-workload-identity \
    --generate-ssh-keys \
    --node-vm-size <VMSize>

# Get the cluster credentials
az aks get-credentials -g $RG -n $CLUSTER_NAME


## Set up the identity

# Get the OIDC Issuer URL
export AKS_OIDC_ISSUER="$(az aks show -n $CLUSTER_NAME -g $RG --query "oidcIssuerProfile.issuerUrl" -otsv)"

# Create the managed identity
az identity create --name wi-demo-identity --resource-group $RG --location $LOC

# Get identity client ID
export USER_ASSIGNED_CLIENT_ID=$(az identity show --resource-group $RG --name wi-demo-identity --query 'clientId' -o tsv)

# Create a service account to federate with the managed identity
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: ${USER_ASSIGNED_CLIENT_ID}
  labels:
    azure.workload.identity/use: "true"
  name: wi-demo-sa
  namespace: default
EOF

# Federate the identity
az identity federated-credential create \
--name wi-demo-federated-id \
--identity-name wi-demo-identity \
--resource-group $RG \
--issuer ${AKS_OIDC_ISSUER} \
--subject system:serviceaccount:default:wi-demo-sa

## Create the Key Vault and Secret

# Create a key vault
az keyvault create --name $KEY_VAULT_NAME --resource-group $RG --location $LOC

# Create a secret
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "Secret" --value "Hello"

# Grant access to the secret for the managed identity
  az keyvault set-policy --name $KEY_VAULT_NAME -g $RG --secret-permissions get --spn "${USER_ASSIGNED_CLIENT_ID}"
# Or run the following command if RBAC is preferred
az role assignment create \
  --assignee "${USER_ASSIGNED_CLIENT_ID}" \
  --role "Key Vault Secrets User" \
  --scope "$(az keyvault show --name $KEY_VAULT_NAME --resource-group $RG --query id -o tsv)"

# Get the version ID
az keyvault secret show --vault-name $KEY_VAULT_NAME --name "Secret" -o tsv --query id

# The version ID is the last part of the resource id above
# We'll use this later
VERSION_ID=ded8e5e3b3e040e9bfa5c47d0e28848a

## ACR Setup

# Create the ACR
az acr create -g $RG -n $ACR_NAME --sku Standard

# Build the image
az acr build -t wi-kv-test -r $ACR_NAME -g $RG .

# Link the ACR to the AKS cluster
az aks update -g $RG -n $CLUSTER_NAME --attach-acr $ACR_NAME

## Deploy the application

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: wi-kv-test
  namespace: default
  labels:
    azure.workload.identity/use: "true"  
spec:
  serviceAccountName: wi-demo-sa
  containers:
    - image: ${ACR_NAME}.azurecr.io/wi-kv-test
      name: wi-kv-test
      env:
      - name: KEY_VAULT_NAME
        value: ${KEY_VAULT_NAME}
      - name: SECRET_NAME
        value: Secret
      - name: VERSION_ID
        value: ${VERSION_ID}       
  nodeSelector:
    kubernetes.io/os: linux
EOF

# Check the pod logs
kubectl logs -f wi-kv-test

# Sample Output
Retrieving your secret from ${KEY_VAULT_NAME}.
Your secret is 'Hello'.