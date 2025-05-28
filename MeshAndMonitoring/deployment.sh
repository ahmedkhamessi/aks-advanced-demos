#Param
export RG_NAME=<ResourceGroupName>
export LOCATION=<Location> # Change this to a region that supports availability zones

# Create resource group
az group create \
--name ${RG_NAME} \
--location ${LOCATION}

# Deploy ARM template
export USER_ID="$(az ad signed-in-user show --query id -o tsv)"

export DEPLOY_NAME="labdemo$(date +%s)"

# Deploy the Lab environment{Log Analytics, Prometheus, Grafana, ACR, Key Vault, User Assigned Managed Identity}
az deployment group create \
--name ${DEPLOY_NAME} \
--resource-group ${RG_NAME} \
--template-uri https://raw.githubusercontent.com/ahmedkhamessi/aks-advanced-demos/refs/heads/main/MeshAndMonitoring/aks-lab-deploy.json \
--parameters userObjectId=${USER_ID} \
--no-wait

# Create a new AKS cluster
export K8S_VERSION=$(az aks get-versions -l ${LOCATION} \
--query "reverse(sort_by(values[?isDefault==true].{version: version}, &version)) | [0] " \
-o tsv)

AKS_NAME=$(az aks create \
--resource-group ${RG_NAME} \
--name meshcluster \
--location ${LOCATION} \
--tier standard \
--kubernetes-version ${K8S_VERSION} \
--os-sku AzureLinux \
--nodepool-name systempool \
--node-count 2 \
--node-vm-size Standard_D4ds_v5 \
--load-balancer-sku standard \
--network-plugin azure \
--network-plugin-mode overlay \
--network-dataplane cilium \
--network-policy cilium \
--enable-managed-identity \
--enable-workload-identity \
--enable-oidc-issuer \
--enable-acns \
--generate-ssh-keys \
--query name -o tsv)

# Get AKS credentials
az aks get-credentials \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--overwrite-existing

# Add a User node pool
az aks nodepool add \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME} \
--mode User \
--name userpool \
--node-count 1

# Taint the system node pool
az aks nodepool update \
--resource-group ${RG_NAME} \
--cluster-name ${AKS_NAME} \
--name systempool \
--node-taints CriticalAddonsOnly=true:NoSchedule

# Export the names and resource IDs of the monitoring resources created by the ARM template
while IFS= read -r line; \
do echo "exporting $line"; \
export $line=$(az deployment group show -g ${RG_NAME} -n ${DEPLOY_NAME} --query "properties.outputs.${line}.value" -o tsv); \
done < <(az deployment group show -g $RG_NAME -n ${DEPLOY_NAME} --query "keys(properties.outputs)" -o tsv)

# enable metrics monitoring on the AKS cluster
# https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=cli#resources-provisioned
az aks update \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--enable-azure-monitor-metrics \
--azure-monitor-workspace-resource-id ${metricsWorkspaceId} \
--grafana-resource-id ${grafanaDashboardId} \
--no-wait

# enable monitoring add-on
az aks enable-addons \
--resource-group ${RG_NAME} \
--name ${AKS_NAME} \
--addon monitoring \
--workspace-resource-id ${logWorkspaceId} \
--no-wait

# Deploy a Demo application

kubectl create namespace pets

kubectl apply -f aks-store-quickstart.yaml -n pets

kubectl get all -n pets

kubectl get svc store-front -n pets

#------- Istio Service Mesh -------#

# Enable Istio add-on
az aks mesh enable \
  --resource-group ${RG_NAME} \
  --name ${AKS_NAME}

# Enable Sidecar Injection
kubectl label namespace pets istio.io/rev=asm-1-24

# Restart the pods to apply the sidecar injection
kubectl rollout restart deployment order-service -n pets
kubectl rollout restart deployment product-service -n pets
kubectl rollout restart deployment store-front -n pets

kubectl rollout restart statefulset rabbitmq -n pets

## Configure mTLS
# deploy a test application to simulate an external client
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: curl-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: curl
  template:
    metadata:
      labels:
        app: curl
    spec:
      containers:
      - name: curl
        image: docker.io/curlimages/curl
        command: ["sleep", "3600"]
EOF
# test sending a request to the store-front service
CURL_POD_NAME="$(kubectl get pod -l app=curl -o jsonpath="{.items[0].metadata.name}")"
kubectl exec -it ${CURL_POD_NAME} -- curl -IL store-front.pets.svc.cluster.local:80

# Apply mTLS for all services in the pets namespace
kubectl apply -n pets -f - <<EOF
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: pets-mtls
  namespace: pets
spec:
  mtls:
    mode: STRICT
EOF

kubectl exec -it ${CURL_POD_NAME} -- curl -IL store-front.pets.svc.cluster.local:80

# Check the status of services inside the Istio mesh

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: curl-inside
  namespace: pets
spec:
  replicas: 1
  selector:
    matchLabels:
      app: curl
  template:
    metadata:
      labels:
        app: curl
    spec:
      containers:
      - name: curl
        image: curlimages/curl
        command: ["sleep", "3600"]
EOF

CURL_INSIDE_POD="$(kubectl get pod -n pets -l app=curl -o jsonpath="{.items[0].metadata.name}")"
kubectl exec -it ${CURL_INSIDE_POD} -n pets -- curl -IL store-front.pets.svc.cluster.local:80

# Check the Istio sidecar logs
kubectl logs -l app=curl -n pets -c istio-proxy

## Expose Services with Istio Ingress Gateway
#Enabling Istio Ingress Gateway
az aks mesh enable-ingress-gateway  \
  --resource-group ${RG_NAME} \
  --name ${AKS_NAME} \
  --ingress-gateway-type external

  kubectl get all -n aks-istio-ingress
# Create an Istio Gateway and VirtualService for the store-front service
#-- a gateway only defines the entry point to the mesh, it does not route traffic by itself --#
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: pets-gateway
  namespace: pets
spec:
  selector:
    istio: aks-istio-ingressgateway-external
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
EOF

#-- Create a VirtualService to route traffic to the store-front service --#
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: pets-route
  namespace: pets
spec:
  hosts:
  - "*"
  gateways:
  - pets-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: store-front
        port:
          number: 80
EOF

# Test the Ingress Gateway
INGRESS_IP=$(kubectl get svc aks-istio-ingressgateway-external -n aks-istio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Ingress Gateway IP: ${INGRESS_IP}"
curl -I http://${INGRESS_IP}/