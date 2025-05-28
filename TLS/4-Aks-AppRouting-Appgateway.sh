# The following script will create an AKS cluster with App routing and Application Gateway
# Set starting environment variables
RG=<your-resource-group-name>
LOC=<your-location>

# Create the Resource Group
az group create -g $RG -l $LOC

# Get the resource group id
RG_ID=$(az group show -g $RG -o tsv --query id)

# Set environment variables for the VNet creation
VNET_NAME=<your-vnet-name>
VNET_ADDRESS_SPACE=10.140.0.0/16
AKS_SUBNET_ADDRESS_SPACE=10.140.0.0/24

# Create the Vnet along with the initial subnet for AKS
az network vnet create \
-g $RG \
-n $VNET_NAME \
--address-prefix $VNET_ADDRESS_SPACE \
--subnet-name aks \
--subnet-prefix $AKS_SUBNET_ADDRESS_SPACE 

# Get a subnet resource ID, which we'll need when we create the AKS cluster
VNET_SUBNET_ID=$(az network vnet subnet show -g $RG --vnet-name $VNET_NAME -n aks -o tsv --query id)

# NOTE: Make sure you give your cluster a unique name
CLUSTER_NAME=<your-cluster-name>

# Cluster Creation Command
az aks create \
-g $RG \
-n $CLUSTER_NAME \
--node-vm-size Standard_D4ds_v5 \
--node-count 2 \
--enable-oidc-issuer \
--enable-workload-identity \
--enable-addons azure-keyvault-secrets-provider \
--vnet-subnet-id $VNET_SUBNET_ID \
--generate-ssh-keys

# Get credentials
az aks get-credentials -g $RG -n $CLUSTER_NAME

# Setup Workload Identity
# Set the namespace where we will deploy our app and ingress controller
NAMESPACE=default

# Get the OIDC Issuer URL
export AKS_OIDC_ISSUER="$(az aks show -n $CLUSTER_NAME -g $RG --query "oidcIssuerProfile.issuerUrl" -otsv)"

# Get the Tenant ID for later
export IDENTITY_TENANT=$(az account show -o tsv --query tenantId)

# Create the managed identity
az identity create --name nginx-ingress-identity --resource-group $RG --location $LOC

# Get identity client ID
export USER_ASSIGNED_CLIENT_ID=$(az identity show --resource-group $RG --name nginx-ingress-identity --query 'clientId' -o tsv)

# Create a service account to federate with the managed identity
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: ${USER_ASSIGNED_CLIENT_ID}
  labels:
    azure.workload.identity/use: "true"
  name: nginx-ingress-sa
  namespace: ${NAMESPACE}
EOF

# Federate the identity
az identity federated-credential create \
--name nginx-ingress-federated-id \
--identity-name nginx-ingress-identity \
--resource-group $RG \
--issuer ${AKS_OIDC_ISSUER} \
--subject system:serviceaccount:${NAMESPACE}:nginx-ingress-sa

## Create the Azure Keyvault

# Create a key vault name
KEY_VAULT_NAME=e2elab$RANDOM

# Create the key vaule
az keyvault create --name $KEY_VAULT_NAME --resource-group $RG --location $LOC --enable-rbac-authorization false

# Grant access to the secret for the managed identity
az keyvault set-policy --name $KEY_VAULT_NAME -g $RG --certificate-permissions get --spn "${USER_ASSIGNED_CLIENT_ID}"
az keyvault set-policy --name $KEY_VAULT_NAME -g $RG --secret-permissions get --spn "${USER_ASSIGNED_CLIENT_ID}"

## Create a certificate in Azure App Certificate or self signed certificate in PFX format
APP_CERT_NAME=<your-app-certificate-name>
# |--> az keyvault certificate import --vault-name $KEY_VAULT_NAME --name $APP_CERT_NAME --file $APP_CERT_NAME.pfx

# Setup the Key Vault CSI secret provider

cat << EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: crashoverride-tls
  namespace: ${NAMESPACE}
spec:
  provider: azure
  secretObjects:                            # secretObjects defines the desired state of synced K8s secret objects
    - secretName: crashoverride-tls-csi
      type: kubernetes.io/tls
      data:
        - objectName: crashoverride
          key: crashoverride.key
        - objectName: crashoverride
          key: crashoverride.crt
  parameters:
    usePodIdentity: "false"
    clientID: ${USER_ASSIGNED_CLIENT_ID}
    keyvaultName: ${KEY_VAULT_NAME}                 # the name of the AKV instance
    objects: |
      array:
        - |
          objectName: crashoverride
          objectType: secret
    tenantId: ${IDENTITY_TENANT}                    # the tenant ID of the AKV instance
EOF

# Deploy the Ingress controller

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Generate the values file we'll use to deploy ingress-nginx
cat <<EOF > nginx-ingress-values.yaml
serviceAccount:
  create: false
  name: nginx-ingress-sa
controller:
  replicaCount: 2
  service:
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
      service.beta.kubernetes.io/azure-pls-create: "true"
  extraVolumes:
      - name: crashoverride-secret-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "crashoverride-tls"
  extraVolumeMounts:
      - name: crashoverride-secret-store
        mountPath: "/mnt/crashoverride"
        readOnly: true
EOF

# Deploy ingress-nginx
helm install e2elab-ic ingress-nginx/ingress-nginx \
    --namespace $NAMESPACE \
    -f nginx-ingress-values.yaml


# Deploy sample app

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aks-helloworld
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aks-helloworld
  template:
    metadata:
      labels:
        app: aks-helloworld
    spec:
      containers:
      - name: aks-helloworld
        image: cilium/echoserver
        ports:
        - containerPort: 8080
        env:
        - name: PORT
          value: '8080'
---
apiVersion: v1
kind: Service
metadata:
  name: aks-helloworld
spec:
  type: ClusterIP
  ports:
  - port: 8080
  selector:
    app: aks-helloworld
EOF

# Deploy the ingress definition

cat <<EOF|kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: crashoverride-ingress-tls
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - e2elab.crashoverride.nyc
    secretName: crashoverride-tls-csi
  rules:
  - host: e2elab.crashoverride.nyc
    http:
      paths:
      - path: /hello-world
        pathType: Prefix
        backend:
          service:
            name: aks-helloworld
            port:
              number: 8080
EOF