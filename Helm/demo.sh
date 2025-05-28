# Parameters
RG=<ResourceGroupName>
LOC=<Location>
CLUSTER_NAME=<AKSClusterName>
UNIQUE_ID=$CLUSTER_NAME$RANDOM
ACR_NAME=$UNIQUE_ID

# Create the resource group
az group create -g $RG -l $LOC

# Create the cluster
az aks create -g $RG -n $CLUSTER_NAME \
    --node-count 1 \
    --generate-ssh-keys \
    --node-vm-size Standard_D4ds_v5

# Get the cluster credentials
az aks get-credentials -g $RG -n $CLUSTER_NAME

# Create an ACR
az acr create -g $RG -n $ACR_NAME --sku Standard

# Link the ACR to the AKS cluster
az aks update -g $RG -n $CLUSTER_NAME --attach-acr $ACR_NAME

# Create the Helm Chart
helm create buildchart 

# Override The container image

```
image:
  repository: stefanprodan/podinfo # change this
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion.
  tag: "" # you can specify image tag here or in Chart.yaml
```
# Change the AppVersion in the Chart.yaml
# Add containerPort and edit the deployment.yaml
```
containerPort: 9898
```
# Package and Push chart to ACR
helm package .

## Resource: https://learn.microsoft.com/en-us/azure/container-registry/container-registry-helm-repos#authenticate-with-the-registry

USER_NAME="00000000-0000-0000-0000-000000000000"
PASSWORD=$(az acr login --name $ACR_NAME --expose-token --output tsv --query accessToken)


helm registry login $ACR_NAME.azurecr.io \
  --username $USER_NAME \
  --password $PASSWORD

helm push buildchart-0.1.0.tgz oci://$ACR_NAME.azurecr.io/helm

az acr manifest list-metadata \
  --registry $ACR_NAME \
  --name helm/buildchart

# Test on a Kubernetes cluster
helm install myhelmdemo oci://$ACR_NAME.azurecr.io/helm/buildchart --version 0.1.0